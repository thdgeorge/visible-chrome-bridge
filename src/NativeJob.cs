using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace VisibleChromeBridge
{
    // No shell, no inherited job handle, no interval in which children can escape.
    public sealed class NativeJob : IDisposable
    {
        private IntPtr job;
        private IntPtr process;

        [StructLayout(LayoutKind.Sequential)] private struct IO_COUNTERS
        { public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount, ReadTransferCount, WriteTransferCount, OtherTransferCount; }
        [StructLayout(LayoutKind.Sequential)] private struct BASIC_LIMITS
        {
            public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass, SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)] private struct EXTENDED_LIMITS
        {
            public BASIC_LIMITS BasicLimitInformation;
            public IO_COUNTERS IoInfo;
            public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct STARTUPINFO
        {
            public uint cb;
            public string lpReserved, lpDesktop, lpTitle;
            public uint dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            public ushort wShowWindow, cbReserved2;
            public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }
        [StructLayout(LayoutKind.Sequential)] private struct PROCESS_INFORMATION
        { public IntPtr hProcess, hThread; public uint dwProcessId, dwThreadId; }
        [StructLayout(LayoutKind.Sequential)] private struct SECURITY_ATTRIBUTES
        { public int nLength; public IntPtr lpSecurityDescriptor; [MarshalAs(UnmanagedType.Bool)] public bool bInheritHandle; }
        [StructLayout(LayoutKind.Sequential)] private struct STARTUPINFOEX
        { public STARTUPINFO StartupInfo; public IntPtr lpAttributeList; }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref EXTENDED_LIMITS info, uint length);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool CreateProcess(string application, StringBuilder command, IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint flags, IntPtr environment, string cwd, ref STARTUPINFOEX startup, out PROCESS_INFORMATION info);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, IntPtr attribute, IntPtr value, IntPtr size, IntPtr previous, IntPtr returnedSize);
        [DllImport("kernel32.dll")] private static extern void DeleteProcThreadAttributeList(IntPtr list);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern IntPtr CreateFile(string name, uint access, uint share, ref SECURITY_ATTRIBUTES attributes, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint ResumeThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool TerminateProcess(IntPtr process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
        [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern uint GetFinalPathNameByHandle(IntPtr handle, StringBuilder path, uint length, uint flags);

        public static string ResolveFilePath(string path)
        {
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            {
                StringBuilder buffer = new StringBuilder(32768);
                uint length = GetFinalPathNameByHandle(stream.SafeFileHandle.DangerousGetHandle(), buffer, (uint)buffer.Capacity, 0);
                if (length == 0 || length >= buffer.Capacity) throw new Win32Exception();
                string result = buffer.ToString();
                return result.StartsWith(@"\\?\", StringComparison.Ordinal) ? result.Substring(4) : result;
            }
        }

        public static string QuoteArgument(string value)
        {
            if (value == null) throw new ArgumentNullException("value");
            StringBuilder result = new StringBuilder("\"");
            int slashes = 0;
            foreach (char c in value)
            {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') result.Append('\\', slashes * 2 + 1);
                else result.Append('\\', slashes);
                result.Append(c);
                slashes = 0;
            }
            result.Append('\\', slashes * 2).Append('"');
            return result.ToString();
        }

        public NativeJob(string executable, string[] arguments, string cwd, IDictionary<string, string> environment)
        {
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            IntPtr block = IntPtr.Zero;
            IntPtr nul = new IntPtr(-1);
            IntPtr attributes = IntPtr.Zero;
            IntPtr handles = IntPtr.Zero;
            bool attributesInitialized = false;
            try
            {
                job = CreateJobObject(IntPtr.Zero, null);
                if (job == IntPtr.Zero) throw new Win32Exception();
                EXTENDED_LIMITS limits = new EXTENDED_LIMITS();
                limits.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
                if (!SetInformationJobObject(job, 9, ref limits, (uint)Marshal.SizeOf(limits))) throw new Win32Exception();
                SECURITY_ATTRIBUTES sa = new SECURITY_ATTRIBUTES();
                sa.nLength = Marshal.SizeOf(sa);
                sa.bInheritHandle = true;
                nul = CreateFile("NUL", 0xC0000000, 3, ref sa, 3, 0, IntPtr.Zero);
                if (nul == new IntPtr(-1)) throw new Win32Exception();
                IntPtr attributeSize = IntPtr.Zero;
                InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref attributeSize);
                attributes = Marshal.AllocHGlobal(attributeSize);
                if (!InitializeProcThreadAttributeList(attributes, 1, 0, ref attributeSize)) throw new Win32Exception();
                attributesInitialized = true;
                handles = Marshal.AllocHGlobal(IntPtr.Size);
                Marshal.WriteIntPtr(handles, nul);
                if (!UpdateProcThreadAttribute(attributes, 0, new IntPtr(0x20002), handles,
                    new IntPtr(IntPtr.Size), IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception();
                STARTUPINFOEX si = new STARTUPINFOEX();
                si.StartupInfo.cb = (uint)Marshal.SizeOf(si);
                si.StartupInfo.dwFlags = 0x100; // STARTF_USESTDHANDLES
                si.StartupInfo.hStdInput = si.StartupInfo.hStdOutput = si.StartupInfo.hStdError = nul;
                si.lpAttributeList = attributes; // PROC_THREAD_ATTRIBUTE_HANDLE_LIST: only NUL.
                List<string> keys = new List<string>(environment.Keys);
                keys.Sort(StringComparer.OrdinalIgnoreCase);
                StringBuilder env = new StringBuilder();
                foreach (string key in keys) env.Append(key).Append('=').Append(environment[key]).Append('\0');
                env.Append('\0');
                block = Marshal.StringToHGlobalUni(env.ToString());
                StringBuilder command = new StringBuilder(QuoteArgument(executable));
                foreach (string argument in arguments) command.Append(' ').Append(QuoteArgument(argument));
                if (!CreateProcess(executable, command, IntPtr.Zero, IntPtr.Zero, true,
                    0x08080404, block, cwd, ref si, out pi)) throw new Win32Exception();
                if (!AssignProcessToJobObject(job, pi.hProcess)) throw new Win32Exception();
                if (ResumeThread(pi.hThread) == uint.MaxValue) throw new Win32Exception();
                process = pi.hProcess;
                pi.hProcess = IntPtr.Zero;
            }
            catch
            {
                if (pi.hProcess != IntPtr.Zero) TerminateProcess(pi.hProcess, 1);
                Dispose();
                throw;
            }
            finally
            {
                if (pi.hThread != IntPtr.Zero) CloseHandle(pi.hThread);
                if (pi.hProcess != IntPtr.Zero) CloseHandle(pi.hProcess);
                if (nul != new IntPtr(-1)) CloseHandle(nul);
                if (attributesInitialized) DeleteProcThreadAttributeList(attributes);
                if (attributes != IntPtr.Zero) Marshal.FreeHGlobal(attributes);
                if (handles != IntPtr.Zero) Marshal.FreeHGlobal(handles);
                if (block != IntPtr.Zero) Marshal.FreeHGlobal(block);
            }
        }

        public bool IsRunning
        {
            get
            {
                uint code;
                return process != IntPtr.Zero && GetExitCodeProcess(process, out code) && code == 259;
            }
        }

        public void Dispose()
        {
            if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
            if (process != IntPtr.Zero) { CloseHandle(process); process = IntPtr.Zero; }
        }
    }
}
