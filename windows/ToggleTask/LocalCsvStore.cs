using System.IO;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Jint;

namespace ToggleTask;

public sealed record DesktopSnapshot(IReadOnlyList<Project> Projects, List<TimeSession> Sessions, TimeSession? Active, string? WorkerId);
public sealed class LocalCsvStore(string file) {
    private byte[]? lastRead;
    private readonly Lazy<Engine> codec = new(() => {
        using var stream = typeof(LocalCsvStore).Assembly.GetManifestResourceStream("TaskTrack.CsvCodec")
            ?? throw new InvalidDataException("CSV codec is missing.");
        using var reader = new StreamReader(stream);
        return new Engine().Execute(reader.ReadToEnd()).Execute("var encodeCsv=TaskTrackCSV.encodeDesktop, decodeCsv=TaskTrackCSV.decodeDesktop;");
    });
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) {
        Converters = { new JsonStringEnumConverter(), new Milliseconds() }
    };
    private sealed class Milliseconds : JsonConverter<DateTime> {
        public override DateTime Read(ref Utf8JsonReader r, Type type, JsonSerializerOptions options) =>
            DateTimeOffset.FromUnixTimeMilliseconds(r.GetInt64()).LocalDateTime;
        public override void Write(Utf8JsonWriter w, DateTime dt, JsonSerializerOptions options) =>
            w.WriteNumberValue(new DateTimeOffset(dt.ToUniversalTime()).ToUnixTimeMilliseconds());
    }
    private byte[]? Current() {
        try { return File.ReadAllBytes(file); }
        catch(FileNotFoundException) { return null; }
        catch(DirectoryNotFoundException) { return null; }
    }
    public DesktopSnapshot? Read() {
        var data=Current();
        if(data==null)return null;
        var result=JsonSerializer.Deserialize<DesktopSnapshot>(
            codec.Value.Invoke("decodeCsv",Encoding.UTF8.GetString(data)).ToString(),Json)
            ?? throw new InvalidDataException("Missing CSV data.");
        lastRead=data;
        return result;
    }
    public void Write(DesktopSnapshot snapshot) {
        var text=codec.Value.Invoke("encodeCsv",JsonSerializer.Serialize(snapshot,Json)).ToString();
        codec.Value.Invoke("decodeCsv",text);
        var data=Encoding.UTF8.GetBytes(text);
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var temp=file+"."+Guid.NewGuid().ToString("N")+".tmp";
        try {
            using var guard=new FileStream(file+".lock",FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
            var current=Current();
            if((current==null)!=(lastRead==null) || (current!=null && !current.AsSpan().SequenceEqual(lastRead)))
                throw new IOException("The CSV changed. Reopen the app.");
            File.WriteAllBytes(temp,data);
            File.Move(temp,file,true);
            lastRead=data;
        } finally { File.Delete(temp); }
    }
}
