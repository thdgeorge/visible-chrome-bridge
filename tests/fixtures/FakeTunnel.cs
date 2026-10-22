using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

// Offline stand-in for lifecycle tests. Never contacts OpenAI or Chrome.
public static class FakeTunnel
{
    public static void Main(string[] args)
    {
        string healthFile = null;
        for (int i = 0; i < args.Length - 1; i++)
            if (args[i] == "--health.url-file") healthFile = args[i + 1];
        if (healthFile == null) Environment.Exit(2);
        TcpListener listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        int port = ((IPEndPoint)listener.LocalEndpoint).Port;
        File.WriteAllText(healthFile, "http://127.0.0.1:" + port);
        File.WriteAllText(Path.Combine(Path.GetDirectoryName(healthFile), "fake-started.json"),
            "{\"pid\":" + System.Diagnostics.Process.GetCurrentProcess().Id +
            ",\"hasKey\":" + (Environment.GetEnvironmentVariable("CONTROL_PLANE_API_KEY") != null ? "true" : "false") +
            ",\"ambientSecret\":" + (Environment.GetEnvironmentVariable("OPENAI_UNRELATED_SECRET") != null ? "true" : "false") + "}");
        while (true)
        {
            using (TcpClient client = listener.AcceptTcpClient())
            using (NetworkStream stream = client.GetStream())
            {
                byte[] request = new byte[4096];
                stream.ReadTimeout = 2000;
                stream.Read(request, 0, request.Length);
                byte[] response = Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK");
                stream.Write(response, 0, response.Length);
            }
        }
    }
}
