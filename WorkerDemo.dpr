program WorkerDemo;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {Form1},
  uWorker in 'uWorker.pas',
  uDSiWin32 in 'uDSiWin32.pas',
  uMsgThread in 'uMsgThread.pas',
  uMsgThread0 in 'uMsgThread0.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
