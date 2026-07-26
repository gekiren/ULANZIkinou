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
using System.Collections.Generic;

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    [PreserveSig] int Activate([In] ref Guid id, [In] int clsCtx, [In] IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePtr);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int f(); int g(); int h(); int i();
    [PreserveSig] int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
    int j();
    [PreserveSig] int GetMasterVolumeLevelScalar(out float pfLevel);
    int k(); int l(); int m(); int n();
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume {
    [PreserveSig] int SetMasterVolume(float fLevel, [In] ref Guid EventContext);
    [PreserveSig] int GetMasterVolume(out float pfLevel);
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, [In] ref Guid EventContext);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

[Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
    [PreserveSig] int GetState(out int state);
    [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string Value, [In] ref Guid EventContext);
    [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string Value, [In] ref Guid EventContext);
    [PreserveSig] int GetGroupingParam(out Guid GroupingParam);
    [PreserveSig] int SetGroupingParam([In] ref Guid Override, [In] ref Guid EventContext);
    [PreserveSig] int RegisterAudioSessionNotification(IntPtr NewNotifications);
    [PreserveSig] int UnregisterAudioSessionNotification(IntPtr NewNotifications);
    [PreserveSig] int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    [PreserveSig] int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    [PreserveSig] int GetProcessId(out int retvVal);
    [PreserveSig] int IsSystemSoundsSession();
    [PreserveSig] int SetDuckingPreference(bool optOut);
}

[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator {
    [PreserveSig] int GetCount(out int SessionCount);
    [PreserveSig] int GetSession(int SessionCount, out IAudioSessionControl2 Session);
}

[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 {
    [PreserveSig] int GetAudioEndpointVolume([MarshalAs(UnmanagedType.LPWStr)] string sessionID, int flags, out IntPtr AudioEndpointVolume);
    [PreserveSig] int GetSimpleAudioVolume([In] ref Guid AudioSessionGuid, int flags, out ISimpleAudioVolume AudioVolume);
    [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator SessionEnum);
}

public class AudioControl {
    private static Guid IID_IAudioEndpointVolume = typeof(IAudioEndpointVolume).GUID;
    private static Guid IID_IAudioSessionManager2 = typeof(IAudioSessionManager2).GUID;

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    private static HashSet<string> IgnoredSystemApps = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
        "UlanziDeck", "UlanziStudio", "ApplicationFrameHost", "SearchHost",
        "ShellExperienceHost", "TextInputHost", "SystemSettings", "explorer", "cmd", "powershell"
    };

    public static string GetForegroundAppName() {
        IntPtr hwnd = GetForegroundWindow();
        IntPtr curr = hwnd;
        for (int i = 0; i < 20; i++) {
            if (curr == IntPtr.Zero) break;
            if (IsWindowVisible(curr)) {
                int pid = 0;
                GetWindowThreadProcessId(curr, out pid);
                if (pid > 0) {
                    try {
                        Process p = Process.GetProcessById(pid);
                        string name = p.ProcessName;
                        if (!string.IsNullOrEmpty(name) && !IgnoredSystemApps.Contains(name)) {
                            return name;
                        }
                    } catch {}
                }
            }
            curr = GetWindow(curr, 2); // GW_HWNDNEXT = 2
        }
        return "Unknown";
    }

    private static IMMDevice GetDefaultDevice() {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDevice device = null;
        if (enumerator.GetDefaultAudioEndpoint(0, 1, out device) != 0) return null;
        return device;
    }

    private static IAudioEndpointVolume GetVolumeControl(string deviceName) {
        IMMDevice device = GetDefaultDevice();
        if (device == null) return null;

        object volumeObj = null;
        Guid iid = IID_IAudioEndpointVolume;
        if (device.Activate(ref iid, 23, IntPtr.Zero, out volumeObj) == 0 && volumeObj != null) {
            return volumeObj as IAudioEndpointVolume;
        }
        return null;
    }

    private static IAudioSessionManager2 GetSessionManager() {
        IMMDevice device = GetDefaultDevice();
        if (device == null) return null;

        object mgrObj = null;
        Guid iid = IID_IAudioSessionManager2;
        if (device.Activate(ref iid, 23, IntPtr.Zero, out mgrObj) == 0 && mgrObj != null) {
            return mgrObj as IAudioSessionManager2;
        }
        return null;
    }

    private static List<ISimpleAudioVolume> GetMatchingAppSessions(out string matchedAppName) {
        matchedAppName = GetForegroundAppName();
        var list = new List<ISimpleAudioVolume>();
        if (string.IsNullOrEmpty(matchedAppName) || matchedAppName.Equals("Unknown", StringComparison.OrdinalIgnoreCase)) {
            return list;
        }

        IAudioSessionManager2 mgr = GetSessionManager();
        if (mgr == null) return list;

        IAudioSessionEnumerator sessionEnum = null;
        if (mgr.GetSessionEnumerator(out sessionEnum) != 0 || sessionEnum == null) return list;

        int count = 0;
        sessionEnum.GetCount(out count);

        for (int i = 0; i < count; i++) {
            IAudioSessionControl2 ctrl2 = null;
            if (sessionEnum.GetSession(i, out ctrl2) != 0 || ctrl2 == null) continue;

            int pid = 0;
            ctrl2.GetProcessId(out pid);
            if (pid <= 0) continue;

            try {
                Process p = Process.GetProcessById(pid);
                if (string.Equals(p.ProcessName, matchedAppName, StringComparison.OrdinalIgnoreCase)) {
                    ISimpleAudioVolume vol = ctrl2 as ISimpleAudioVolume;
                    if (vol != null) {
                        list.Add(vol);
                    }
                }
            } catch {}
        }
        return list;
    }

    // --- Master Volume APIs ---

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

    // --- Foreground App Volume APIs ---

    public static float GetForegroundVolume() {
        string appName;
        var sessions = GetMatchingAppSessions(out appName);
        if (sessions.Count == 0) return -1f;

        float total = 0f;
        int valid = 0;
        foreach (var vol in sessions) {
            float level = 0f;
            if (vol.GetMasterVolume(out level) == 0) {
                total += level;
                valid++;
            }
        }
        return valid > 0 ? (total / valid) : -1f;
    }

    public static bool SetForegroundVolume(float level) {
        string appName;
        var sessions = GetMatchingAppSessions(out appName);
        if (sessions.Count == 0) return false;

        Guid emptyGuid = Guid.Empty;
        bool success = false;
        foreach (var vol in sessions) {
            if (vol.SetMasterVolume(level, ref emptyGuid) == 0) {
                success = true;
            }
        }
        return success;
    }

    public static int GetForegroundMute() {
        string appName;
        var sessions = GetMatchingAppSessions(out appName);
        if (sessions.Count == 0) return -1;

        bool mute = false;
        foreach (var vol in sessions) {
            if (vol.GetMute(out mute) == 0 && mute) {
                return 1;
            }
        }
        return 0;
    }

    public static bool SetForegroundMute(bool mute) {
        string appName;
        var sessions = GetMatchingAppSessions(out appName);
        if (sessions.Count == 0) return false;

        Guid emptyGuid = Guid.Empty;
        bool success = false;
        foreach (var vol in sessions) {
            if (vol.SetMute(mute, ref emptyGuid) == 0) {
                success = true;
            }
        }
        return success;
    }
}
"@

Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue

switch ($Action) {
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
