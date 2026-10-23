$ErrorActionPreference = "Stop"

$source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.Threading;

public static class DfgtNativeSwitch {
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

  public static void Run() {
    byte[] native1 = new byte[] {0xf8,0x0a,0x00,0x00,0x00,0x00,0x00,0x00};
    byte[] native2 = new byte[] {0xf8,0x09,0x03,0x01,0x00,0x00,0x00,0x00};
    byte[] range900 = new byte[] {0xf8,0x81,0x84,0x03,0x00,0x00,0x00,0x00};

    List<string> fallbackPaths = Find("c294");
    foreach (string path in fallbackPaths) {
      Send(path, native1);
      Thread.Sleep(250);
      Send(path, native2);
    }

    if (fallbackPaths.Count > 0) {
      Thread.Sleep(4500);
    }

    List<string> nativePaths = Find("c29a");
    foreach (string path in nativePaths) {
      Send(path, range900);
    }

    Console.WriteLine("Fallback C294 paths: " + fallbackPaths.Count);
    Console.WriteLine("Native C29A paths: " + nativePaths.Count);
    Console.WriteLine(nativePaths.Count > 0 ? "DFGT native mode command sent." : "DFGT native mode not detected.");
  }
}
'@

Add-Type -TypeDefinition $source -Language CSharp
[DfgtNativeSwitch]::Run()