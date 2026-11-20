namespace ToggleTask;
public enum ProjectStatus { Pending, Active, Closed }
public sealed record Project(string Id,string Name,string Client,string Area,ProjectStatus Status,int HistoricalMinutes,string[] Participants,string[] WorkTypes);
public sealed record TimeSession(string Id,string ProjectId,string ProjectName,string Description,DateTime StartedAt,DateTime? EndedAt,int DurationSeconds,string RecordedBy,string Source,string? WorkerId=null) { public string DedupeKey => Id; }
public static class SessionPolicy {
 public static IEnumerable<TimeSession> Owned(IEnumerable<TimeSession> sessions,string? workerId) => string.IsNullOrWhiteSpace(workerId) ? [] : sessions.Where(s=>s.WorkerId==workerId);
 public static double Overlap(TimeSession s,DateTime start,DateTime end) => Math.Max(0,(new[]{s.EndedAt??s.StartedAt,end}.Min()-new[]{s.StartedAt,start}.Max()).TotalSeconds);
}
public static class MockData { public static readonly IReadOnlyList<Project> Projects = [new("job-001","Carolina Herrera — Good Girl","Carolina Herrera","Good Girl",ProjectStatus.Active,1420,["Javier","Carla"],["Visuales","Artes finales"]),new("job-002","Rabanne — Christmas 2026","Rabanne","XMAS",ProjectStatus.Pending,860,["Nidia"],["Propuestas"]),new("job-003","L’Artisan Parfumeur — Gifting","L’Artisan Parfumeur","Gifting",ProjectStatus.Active,430,["Javier","Paula"],["Visuales"])]; }
