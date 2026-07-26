param (
    [string]$Action,
    [string]$DeviceName,
    [double]$Value
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$csharpCode = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey {
    public Guid fmtid;
    public int pid;
}

[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
    [FieldOffset(0)] public short vt;
    [FieldOffset(8)] public IntPtr ptr;
    
    public string GetString() {
        if (vt == 31 && ptr != IntPtr.Zero) {
            return Marshal.PtrToStringUni(ptr);
        }
        return null;
    }
}

[Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPropertyStore {
    int GetCount(out int cProps);
    int GetAt(int iProp, out PropertyKey key);
    int GetValue(ref PropertyKey key, out PropVariant pv);
    int SetValue(ref PropertyKey key, ref PropVariant pv);
    int Commit();
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int f(); int g(); int h(); int i();
    int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
    int j();
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int k(); int l(); int m(); int n();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
    int OpenPropertyStore(int stgmAccess, out IPropertyStore properties);
    int GetId(out string ppstrId);
    int GetState(out int pdwState);
}

[Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCollection {
    int GetCount(out int pcDevices);
    int Item(int nDevice, out IMMDevice device);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    int GetDevice(string pwstrId, out IMMDevice endpoint);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

// --- Application Session Volume Interfaces ---

[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume {
    int SetMasterVolume(float fLevel, Guid EventContext);
    int GetMasterVolume(out float pfLevel);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid EventContext);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

[Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl {
    int GetState(out int state);
    int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string Value, Guid EventContext);
    int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string Value, Guid EventContext);
    int GetGroupingParam(out Guid GroupingParam);
    int SetGroupingParam(Guid Override, Guid EventContext);
    int RegisterAudioSessionNotification(IntPtr NewNotifications);
    int UnregisterAudioSessionNotification(IntPtr NewNotifications);
}

[Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
    int GetState(out int state);
    int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string Value, Guid EventContext);
    int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string Value, Guid EventContext);
    int GetGroupingParam(out Guid GroupingParam);
    int SetGroupingParam(Guid Override, Guid EventContext);
    int RegisterAudioSessionNotification(IntPtr NewNotifications);
    int UnregisterAudioSessionNotification(IntPtr NewNotifications);
    int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    int GetProcessId(out int retvVal);
    int IsSystemSoundsSession();
    int SetDuckingPreference(bool optOut);
}

[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator {
    int GetCount(out int SessionCount);
    int GetSession(int SessionCount, out IAudioSessionControl Session);
}

[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 {
    int GetSessionEnumerator(out IAudioSessionEnumerator SessionEnum);
    int RegisterSessionNotification(IntPtr SessionNotification);
    int UnregisterSessionNotification(IntPtr SessionNotification);
    int RegisterDuckNotification([MarshalAs(UnmanagedType.LPWStr)] string sessionID, IntPtr duckNotification);
    int UnregisterDuckNotification(IntPtr duckNotification);
}

public class AudioControl {
    private static Guid IID_IAudioEndpointVolume = typeof(IAudioEndpointVolume).GUID;
    private static Guid IID_IAudioSessionManager2 = typeof(IAudioSessionManager2).GUID;
    private static PropertyKey PKEY_Device_FriendlyName = new PropertyKey {
        fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"),
        pid = 14
    };

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    private static IMMDevice FindDevice(string searchName) {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDeviceCollection collection = null;
        if (enumerator.EnumAudioEndpoints(0, 1, out collection) != 0) return null;
        
        int count = 0;
        if (collection.GetCount(out count) != 0) return null;

        for (int i = 0; i < count; i++) {
            IMMDevice device = null;
            if (collection.Item(i, out device) != 0) continue;

            IPropertyStore store = null;
            if (device.OpenPropertyStore(0, out store) == 0) {
                PropVariant pv;
                if (store.GetValue(ref PKEY_Device_FriendlyName, out pv) == 0) {
                    string name = pv.GetString();
                    if (name != null && name.IndexOf(searchName, StringComparison.OrdinalIgnoreCase) >= 0) {
                        return device;
                    }
                }
            }
        }
        return null;
    }

    private static IMMDevice GetDefaultDevice() {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDevice device = null;
        if (enumerator.GetDefaultAudioEndpoint(0, 1, out device) != 0) return null;
        return device;
    }

    private static IAudioEndpointVolume GetVolumeControl(string deviceName) {
        IMMDevice device = null;
        if (string.IsNullOrEmpty(deviceName) || deviceName.Equals("default", StringComparison.OrdinalIgnoreCase)) {
            device = GetDefaultDevice();
        } else {
            device = FindDevice(deviceName);
        }
        if (device == null) return null;

        IAudioEndpointVolume volume = null;
        if (device.Activate(ref IID_IAudioEndpointVolume, 23, 0, out volume) == 0) {
            return volume;
        }
        return null;
    }

    private static int GetForegroundPid() {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return -1;
        int pid = 0;
        GetWindowThreadProcessId(hwnd, out pid);
        return pid;
    }

    // vtable経由でIMMDeviceからIAudioSessionManager2をActivateする
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int ActivateDelegate(IntPtr self, ref Guid iid, int clsCtx, IntPtr pParams, out IntPtr ppv);

    private static IAudioSessionManager2 GetSessionManager() {
        IMMDevice device = GetDefaultDevice();
        if (device == null) return null;

        try {
            IntPtr pDevice = Marshal.GetComInterfaceForObject(device, typeof(IMMDevice));
            if (pDevice == IntPtr.Zero) return null;

            Guid iid = IID_IAudioSessionManager2;
            IntPtr ppv = IntPtr.Zero;

            IntPtr vtable = Marshal.ReadIntPtr(pDevice);
            IntPtr activateFnPtr = Marshal.ReadIntPtr(vtable, 3 * IntPtr.Size);
            var activate = (ActivateDelegate)Marshal.GetDelegateForFunctionPointer(activateFnPtr, typeof(ActivateDelegate));

            int hr = activate(pDevice, ref iid, 23, IntPtr.Zero, out ppv);
            Marshal.Release(pDevice);

            if (hr != 0 || ppv == IntPtr.Zero) return null;

            IAudioSessionManager2 mgr = (IAudioSessionManager2)Marshal.GetObjectForIUnknown(ppv);
            Marshal.Release(ppv);
            return mgr;
        } catch {
            return null;
        }
    }

    private static ISimpleAudioVolume GetForegroundSessionVolume() {
        int targetPid = GetForegroundPid();
        if (targetPid <= 0) return null;

        IAudioSessionManager2 mgr = GetSessionManager();
        if (mgr == null) return null;

        IAudioSessionEnumerator sessionEnum = null;
        if (mgr.GetSessionEnumerator(out sessionEnum) != 0 || sessionEnum == null) return null;

        int count = 0;
        if (sessionEnum.GetCount(out count) != 0) return null;

        for (int i = 0; i < count; i++) {
            IAudioSessionControl ctrl = null;
            if (sessionEnum.GetSession(i, out ctrl) != 0 || ctrl == null) continue;

            IAudioSessionControl2 ctrl2 = ctrl as IAudioSessionControl2;
            if (ctrl2 == null) continue;

            int pid = 0;
            if (ctrl2.GetProcessId(out pid) != 0) continue;
            if (pid != targetPid) continue;

            ISimpleAudioVolume vol = ctrl as ISimpleAudioVolume;
            if (vol != null) return vol;
        }
        return null;
    }

    public static float GetVolume(string deviceName) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return -1f;
        float level = 0f;
        vol.GetMasterVolumeLevelScalar(out level);
        return level;
    }

    public static bool SetVolume(string deviceName, float level) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return false;
        return vol.SetMasterVolumeLevelScalar(level, Guid.Empty) == 0;
    }

    public static int GetMute(string deviceName) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return -1;
        bool mute = false;
        vol.GetMute(out mute);
        return mute ? 1 : 0;
    }

    public static bool SetMute(string deviceName, bool mute) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return false;
        return vol.SetMute(mute, Guid.Empty) == 0;
    }

    public static string GetDevices() {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDeviceCollection collection = null;
        if (enumerator.EnumAudioEndpoints(0, 1, out collection) != 0) return "";
        int count = 0;
        if (collection.GetCount(out count) != 0) return "";
        
        var sb = new StringBuilder();
        for (int i = 0; i < count; i++) {
            IMMDevice device = null;
            if (collection.Item(i, out device) != 0) continue;
            IPropertyStore store = null;
            if (device.OpenPropertyStore(0, out store) == 0) {
                PropVariant pv;
                if (store.GetValue(ref PKEY_Device_FriendlyName, out pv) == 0) {
                    string name = pv.GetString();
                    if (name != null) {
                        sb.AppendLine(name);
                    }
                }
            }
        }
        return sb.ToString();
    }

    // --- Foreground App Volume ---

    public static float GetForegroundVolume() {
        ISimpleAudioVolume vol = GetForegroundSessionVolume();
        if (vol == null) return -1f;
        float level = 0f;
        vol.GetMasterVolume(out level);
        return level;
    }

    public static bool SetForegroundVolume(float level) {
        ISimpleAudioVolume vol = GetForegroundSessionVolume();
        if (vol == null) return false;
        return vol.SetMasterVolume(level, Guid.Empty) == 0;
    }

    public static int GetForegroundMute() {
        ISimpleAudioVolume vol = GetForegroundSessionVolume();
        if (vol == null) return -1;
        bool mute = false;
        vol.GetMute(out mute);
        return mute ? 1 : 0;
    }

    public static bool SetForegroundMute(bool mute) {
        ISimpleAudioVolume vol = GetForegroundSessionVolume();
        if (vol == null) return false;
        return vol.SetMute(mute, Guid.Empty) == 0;
    }

    public static string GetForegroundAppName() {
        int pid = GetForegroundPid();
        if (pid <= 0) return "Unknown";
        try {
            Process proc = Process.GetProcessById(pid);
            return proc.ProcessName;
        } catch {
            return "Unknown";
        }
    }
}
"@

Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue

switch ($Action) {
    "GetDevices" {
        [AudioControl]::GetDevices()
    }
    "GetVolume" {
        [AudioControl]::GetVolume($DeviceName)
    }
    "SetVolume" {
        [AudioControl]::SetVolume($DeviceName, $Value)
    }
    "GetMute" {
        [AudioControl]::GetMute($DeviceName)
    }
    "SetMute" {
        [AudioControl]::SetMute($DeviceName, ($Value -eq 1))
    }
    "GetForegroundVolume" {
        [AudioControl]::GetForegroundVolume()
    }
    "SetForegroundVolume" {
        [AudioControl]::SetForegroundVolume($Value)
    }
    "GetForegroundMute" {
        [AudioControl]::GetForegroundMute()
    }
    "SetForegroundMute" {
        [AudioControl]::SetForegroundMute(($Value -eq 1))
    }
    "GetForegroundAppName" {
        [AudioControl]::GetForegroundAppName()
    }
    default {
        Write-Error "Unknown action: $Action"
    }
}
