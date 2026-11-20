using System.Drawing; using System.Windows; using Forms=System.Windows.Forms;
namespace ToggleTask;
public partial class MainWindow:Window { readonly TimerStore store=new(); readonly Forms.NotifyIcon tray;
 public MainWindow(){InitializeComponent();DataContext=store;tray=new(){Icon=SystemIcons.Application,Text="Task Track",Visible=true};tray.DoubleClick+=(_,_)=>{Show();Activate();};Closed+=(_,_)=>{tray.Visible=false;tray.Dispose();store.Dispose();};}
 void Timer_Click(object s,RoutedEventArgs e)=>store.Submit();
 void Window_KeyDown(object s,System.Windows.Input.KeyEventArgs e){if(e.Key==System.Windows.Input.Key.D&&System.Windows.Input.Keyboard.Modifiers==System.Windows.Input.ModifierKeys.Control){store.ManualMode=!store.ManualMode;e.Handled=true;}}
 void Tracking_Changed(object s,RoutedEventArgs e)=>store.Activity.SetEnabled(((System.Windows.Controls.CheckBox)s).IsChecked==true);
 void ClearActivity_Click(object s,RoutedEventArgs e)=>store.Activity.Clear();
 void Review_Click(object s,RoutedEventArgs e){if(((System.Windows.Controls.Button)s).Tag is AppActivity item)store.Review(item);}
 void Edit_Click(object s,RoutedEventArgs e){if(((System.Windows.Controls.Button)s).Tag is TimeSession item)store.Edit(item);}
 void PreviousDay_Click(object s,RoutedEventArgs e)=>store.SelectedDay=store.SelectedDay.AddDays(-1);
 void NextDay_Click(object s,RoutedEventArgs e)=>store.SelectedDay=store.SelectedDay.AddDays(1);
 void Today_Click(object s,RoutedEventArgs e)=>store.SelectedDay=DateTime.Today;
}
