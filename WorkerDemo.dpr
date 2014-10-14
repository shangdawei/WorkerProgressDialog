program WorkerDemo;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  uWorker in 'uWorker.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
