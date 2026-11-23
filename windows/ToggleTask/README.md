# Task Track — Windows MVP

Native Windows version built with WPF and .NET 8. It includes a timer, project picker, activity description, personal history, simulated projects, stable deduplication IDs, activity suggestions and a system-tray menu. Sessions and an active timer are stored automatically in `%LOCALAPPDATA%\TaskTrack\task-track.csv` when Notion is unavailable.

Run `dotnet run --project windows/ToggleTask/ToggleTask.csproj` on Windows with the .NET 8 SDK. Notion authentication and bidirectional synchronization remain behind the sync boundary for the next production iteration.
