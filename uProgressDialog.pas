unit uProgressDialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, uWorker;

type
  TProgressDialog = class( TForm )
    Label0: TLabel;
    Label1: TLabel;
    ProgressBar1: TProgressBar;
    btnCancel: TButton;
    procedure btnCancelClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure FormCloseQuery( Sender: TObject; var CanClose: Boolean );
  private
    { Private declarations }
    FWorker: TWorker;
    procedure SetMax( Max: Integer );
    procedure SetMin( Min: Integer );
    procedure SetPos( Pos: Integer );
    procedure SetTitle( Title: String );
    procedure SetText0( Text0: String );
    procedure SetText1( Text1: String );
  public
    { Public declarations }
    constructor Create( AOwner: TComponent; AWorker: TWorker ); reintroduce; { overload; }

    property Title: String write SetTitle;
    property Text0: String write SetText0;
    property Text1: String write SetText1;
    property Max: Integer write SetMax;
    property Min: Integer write SetMin;
    property Pos: Integer write SetPos;
  end;

var
  ProgressDialog: TProgressDialog;

implementation

{$R *.dfm}

procedure TProgressDialog.btnCancelClick( Sender: TObject );
begin
  FWorker.TaskCancel( );
end;

constructor TProgressDialog.Create( AOwner: TComponent; AWorker: TWorker );
begin
  inherited Create( AOwner );
  FWorker := AWorker;
end;

procedure TProgressDialog.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin
  btnCancelClick( Self );
end;

procedure TProgressDialog.FormCreate( Sender: TObject );
begin
  FWorker.TaskStart( );
end;

procedure TProgressDialog.SetTitle( Title: String );
begin
  Self.Caption := Title;
end;

procedure TProgressDialog.SetText0( Text0: String );
begin
  Label0.Caption := Text0;
end;

procedure TProgressDialog.SetText1( Text1: String );
begin
  Label1.Caption := Text1;
end;

procedure TProgressDialog.SetMax( Max: Integer );
begin
  ProgressBar1.Max := Max;
end;

procedure TProgressDialog.SetMin( Min: Integer );
begin
  ProgressBar1.Min := Min;
end;

procedure TProgressDialog.SetPos( Pos: Integer );
begin
  ProgressBar1.Position := Pos;
end;

end.
