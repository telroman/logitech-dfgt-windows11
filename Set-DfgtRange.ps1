param(
  [ValidateSet(360,900)][int]$Degrees = 900,
  [ValidateSet('Unchanged','Off','On')][string]$AutoCenter = 'Unchanged'
)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name NeedForSpeedUnbound -ErrorAction SilentlyContinue) {
  throw 'Close Need for Speed Unbound before changing wheel settings.'
}
$source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.Threading;

public static class DfgtRangeControl {
  const int DIGCF_PRESENT = 0x00000002;
  const int DIGCF_DEVICEINTERFACE = 0x00000010;
  const uint GENERIC_READ = 0x80000000;
  const uint GENERIC_WRITE = 0x40000000;
  const uint FILE_SHARE_READ = 0x00000001;
  const uint FILE_SHARE_WRITE = 0x00000002;
  const uint OPEN_EXISTING = 3;

  [StructLayout(LayoutKind.Sequential)]
  struct SP_DEVICE_INTERFACE_DATA {
    public int cbSize;
    public Guid InterfaceClassGuid;
    public int Flags;
    public IntPtr Reserved;
  }

  [DllImport("hid.dll")] static extern void HidD_GetHidGuid(out Guid hidGuid);
  [DllImport("setupapi.dll", SetLastError=true)] static extern IntPtr SetupDiGetClassDevs(ref Guid classGuid, IntPtr enumerator, IntPtr hwndParent, int flags);
  [DllImport("setupapi.dll", SetLastError=true)] static extern bool SetupDiEnumDeviceInterfaces(IntPtr deviceInfoSet, IntPtr deviceInfoData, ref Guid interfaceClassGuid, int memberIndex, ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData);
  [DllImport("setupapi.dll", SetLastError=true, CharSet=CharSet.Auto)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr deviceInfoSet, ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData, IntPtr deviceInterfaceDetailData, int deviceInterfaceDetailDataSize, out int requiredSize, IntPtr deviceInfoData);
  [DllImport("setupapi.dll", SetLastError=true)] static extern bool SetupDiDestroyDeviceInfoList(IntPtr deviceInfoSet);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)] static extern SafeFileHandle CreateFile(string fileName, uint desiredAccess, uint shareMode, IntPtr securityAttributes, uint creationDisposition, uint flagsAndAttributes, IntPtr templateFile);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool WriteFile(SafeFileHandle file, byte[] buffer, uint bytesToWrite, out uint bytesWritten, IntPtr overlapped);
  [DllImport("hid.dll", SetLastError=true)] static extern bool HidD_SetOutputReport(SafeFileHandle hidDeviceObject, byte[] reportBuffer, int reportBufferLength);

  static List<string> Find(string pid) {
    Guid hidGuid;
    HidD_GetHidGuid(out hidGuid);
    IntPtr set = SetupDiGetClassDevs(ref hidGuid, IntPtr.Zero, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    List<string> paths = new List<string>();
    if (set == IntPtr.Zero || set.ToInt64() == -1) return paths;

    try {
      for (int i = 0; ; i++) {
        SP_DEVICE_INTERFACE_DATA data = new SP_DEVICE_INTERFACE_DATA();
        data.cbSize = Marshal.SizeOf(typeof(SP_DEVICE_INTERFACE_DATA));
        if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref hidGuid, i, ref data)) break;

        int required;
        SetupDiGetDeviceInterfaceDetail(set, ref data, IntPtr.Zero, 0, out required, IntPtr.Zero);
        IntPtr detail = Marshal.AllocHGlobal(required);

        try {
          Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
          if (SetupDiGetDeviceInterfaceDetail(set, ref data, detail, required, out required, IntPtr.Zero)) {
            string path = Marshal.PtrToStringAuto(IntPtr.Add(detail, 4));
            if (path != null && path.ToLowerInvariant().Contains("vid_046d&pid_" + pid.ToLowerInvariant())) {
              paths.Add(path);
            }
          }
        } finally {
          Marshal.FreeHGlobal(detail);
        }
      }
    } finally {
      SetupDiDestroyDeviceInfoList(set);
    }

    return paths;
  }

  static bool Send(string path, byte[] report8) {
    using (SafeFileHandle h = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero)) {
      if (h.IsInvalid) return false;

      byte[] reportWithId = new byte[9];
      Buffer.BlockCopy(report8, 0, reportWithId, 1, report8.Length);

      uint written;
      bool ok = HidD_SetOutputReport(h, reportWithId, reportWithId.Length);
      if (!ok) ok = WriteFile(h, reportWithId, (uint)reportWithId.Length, out written, IntPtr.Zero);
      if (!ok) ok = WriteFile(h, report8, (uint)report8.Length, out written, IntPtr.Zero);
      return ok;
    }
  }

  public static void Run(int degrees, string autoCenter) {
    if (degrees != 360 && degrees != 900) throw new ArgumentOutOfRangeException("degrees");
    List<string> paths = Find("c29a");
    if (paths.Count == 0) throw new InvalidOperationException("DFGT C29A not found. Switch to native mode first.");
    byte[] report = new byte[] {0xf8,0x81,(byte)(degrees & 255),(byte)(degrees >> 8),0,0,0,0};
    bool sent = false;
    foreach (string path in paths) sent = Send(path, report) || sent;
    if (!sent) throw new InvalidOperationException("HID output failed. Close games and joy.cpl and retry.");
    Console.WriteLine("Range command accepted by Windows: " + degrees + " degrees. Verify on the wheel.");
    if (autoCenter != "Unchanged") {
      byte[] centerReport = new byte[] {(byte)(autoCenter == "Off" ? 0xf5 : 0x14),0,0,0,0,0,0,0};
      bool centerSent = false;
      foreach (string path in paths) centerSent = Send(path, centerReport) || centerSent;
      if (!centerSent) throw new InvalidOperationException("Range sent, but autocenter HID output failed.");
      Console.WriteLine("Autocenter command accepted by Windows: " + autoCenter + ". Verify resistance on the wheel.");
    }
  }
}
'@
Add-Type -TypeDefinition $source -Language CSharp
[DfgtRangeControl]::Run($Degrees, $AutoCenter)

