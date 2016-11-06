unit uWorker;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes, System.SysUtils,
  System.Generics.Defaults, System.Generics.Collections,
  VCL.Controls, VCL.Forms;

const
  WM_WORKER_STATE_CHANGED = WM_USER + 100;
  WM_WORKER_FEEDBACK_PROGRESS = WM_USER + 101;
  WM_WORKER_FEEDBACK_DATA = WM_USER + 102;

const
  WORKERMGR_WORKER_MAX_NUM = 128;

type
  PWorkerDataRec = ^TWorkerDataRec;

  TWorkerDataRec = record
    Id: Integer;
    DataProcessed: TObject;
  end;

  TTaskState = ( tsStarted, tsSuspended, tsResumed, tsCompleted );
  TTaskResult = ( trCanceled, trSuccessed, trFailed );

  TWorker = class;

  TWorkerTask = function( Worker: TWorker; Param: TObject ): TTaskResult of object;
  TTaskStateChanged = procedure( Sender: TWorker; WorkerState: TTaskState ) of object;
  TTaskProgressChangedEvent = procedure( Sender: TWorker; ProgressChanged: Integer ) of object;
  TTaskDataProcessedEvent = procedure( Sender: TWorker; Id: Integer; DataProcessed: TObject ) of object;

  TWorkerMgr = class;

  TWorker = class( TThread )
    FName: string;
    FTag: Integer;
    FOwner: TWorkerMgr;

    FExecuting: LongBool;
    FAllocedForTask: LongBool;
    FFreeOnTaskComplete: LongBool;

    FFThreadTerminateEvent: THandle;

    FTaskStartEvent: THandle;
    FTaskResumeEvent: THandle;
    FTaskCompletedEvent: THandle;

    FTaskProc: TWorkerTask;
    FTaskParam: TObject;
    FTaskResult: TTaskResult;

    FTaskRunning: LongBool;
    FTaskSuspended: LongBool;
    FTaskCanceling: LongBool;
    FTaskSuspending: LongBool;

    FOnTaskStateChanged: TTaskStateChanged;
    FOnTaskDataProcessed: TTaskDataProcessedEvent;
    FOnTaskProgressChanged: TTaskProgressChangedEvent;

    procedure AfterConstruction; override;

  protected
    procedure Execute; override;

    procedure DoDataProcessed( WorkerDataRec: PWorkerDataRec );
    procedure DoProgressChanged( ProgressChanged: Integer );
    procedure DoStateChanged( CurrentState: TTaskState );

  public
    constructor Create( Owner: TWorkerMgr; Name: string = 'Worker'; Tag: Integer = 0 );
    destructor Destroy; override;

    procedure QueryTaskSuspendPending;
    function IsTaskCancelPending: LongBool;

    procedure TaskProgressChanged( Perent: Integer );
    procedure TaskDataProcessed( DataProcessed: TObject; Id: Integer = 0 );

    procedure TaskStart( TaskProc: TWorkerTask; TaskParam: TObject ); overload;
    procedure TaskStart( ); overload;
    procedure TaskSuspend( );
    procedure TaskResume( );
    procedure TaskCancel( );

    property Tag: Integer read FTag write FTag default 0;
    property FreeOnTaskComplete: LongBool read FFreeOnTaskComplete write FFreeOnTaskComplete;

    property TaskRunning: LongBool read FTaskRunning;
    property TaskProc: TWorkerTask write FTaskProc;
    property TaskParam: TObject write FTaskParam;
    property TaskResult: TTaskResult read FTaskResult;

    property OnTaskStateChanged: TTaskStateChanged read FOnTaskStateChanged write FOnTaskStateChanged;
    property OnTaskDataProcessed: TTaskDataProcessedEvent read FOnTaskDataProcessed write FOnTaskDataProcessed;
    property OnTaskProgressChanged: TTaskProgressChangedEvent read FOnTaskProgressChanged write FOnTaskProgressChanged;
  end;

  EWorkerMgr = class( Exception );

  TWorkerMgr = class( TThread )
  private
    FName: string;
    FCreated: Boolean;

    FThreadWindow: HWND;
    FProcessWindow: HWND;
    FReadyEvent: THandle;
    FException: Exception;

    FWorkerList: TThreadList< TWorker >;

    procedure TerminatedSet; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    function PostThreadMessage( Msg, WParam, LParam: NativeUInt ): LongBool;
    function SendThreadMessage( Msg, WParam, LParam: NativeUInt ): NativeInt;

    function PostProcessMessage( Msg, WParam, LParam: NativeUInt ): LongBool;
    function SendProcessMessage( Msg, WParam, LParam: NativeUInt ): NativeInt;

    procedure CreateThreadWindow;
    procedure DeleteThreadWindow;
    procedure ThreadWndMethod( var Msg: TMessage );

    procedure CreateProcessWindow;
    procedure DeleteProcessWindow;
    procedure ProcessWndMethod( var Msg: TMessage );

    procedure HandleException;
    procedure HandleExceptionProcesshronized;

    procedure Execute; override;
    procedure Idle;

  public
    constructor Create( Name: string = 'WorkerMgr' );
    destructor Destroy; override;

    function AllocWorker( Name: string = 'Worker'; Tag: Integer = 0 ): TWorker;
    procedure FreeWorker( Worker: TWorker );
  end;

const
  WorkerResultText: array [ trCanceled .. trFailed ] of string = ( 'Canceled', 'Successed', 'Failed' );

var
  WorkerMgr: TWorkerMgr;

implementation

{ TWorker }

const
  WM_TERMINATE_WORKER_MGR = WM_APP;

procedure TWorker.TaskDataProcessed( DataProcessed: TObject; Id: Integer );
var
  WorkerDataRec: PWorkerDataRec;
begin
  if Assigned( FOnTaskDataProcessed ) then
  begin
    New( WorkerDataRec );

    WorkerDataRec.Id := Id;
    WorkerDataRec.DataProcessed := DataProcessed;
    FOwner.SendProcessMessage( WM_WORKER_FEEDBACK_DATA, NativeUInt( Self ), NativeUInt( WorkerDataRec ) );

    Dispose( WorkerDataRec );
  end;
end;

procedure TWorker.TaskProgressChanged( Perent: Integer );
begin
  if Assigned( FOnTaskProgressChanged ) then
    FOwner.SendProcessMessage( WM_WORKER_FEEDBACK_PROGRESS, NativeUInt( Self ), NativeUInt( Perent ) )
end;

procedure TWorker.TaskStart;
begin
  while not FExecuting do // Wait until Thread is executing
    Yield;

  SetEvent( Self.FTaskStartEvent ); // StartTask Task
end;

procedure TWorker.TaskSuspend;
begin
  if not FTaskRunning then
    Exit;

  if not FTaskSuspended then
    FTaskSuspending := True;
end;

procedure TWorker.TaskResume;
begin
  if not FTaskRunning then
    Exit;

  if FTaskSuspended then
    SetEvent( FTaskResumeEvent );
end;

procedure TWorker.TaskCancel;
var
  Wait: DWORD;
begin
  if not FTaskRunning then
    Exit;

  TaskResume( ); // ResumeTask if Task has been suspended

  FTaskCompletedEvent := CreateEvent( nil, True, FALSE, '' );

  // Let Task know it need be canceled
  FTaskCanceling := True;

  while True do
  begin
    // Wait until Task Exit
    Wait := MsgWaitForMultipleObjects( 1, FTaskCompletedEvent, FALSE, INFINITE, QS_ALLINPUT );

    if Wait = WAIT_OBJECT_0 then
    begin
      ResetEvent( FTaskCompletedEvent );
      CloseHandle( FTaskCompletedEvent );
      Exit;
    end;

    Application.ProcessMessages( );
  end;
end;

{
  Yield() : SwitchToThread ()

  Causes the calling thread to yield execution to another thread
  that is ready to run on the current processor.
  The operating system selects the next thread to be executed.
}
procedure TWorker.TaskStart( TaskProc: TWorkerTask; TaskParam: TObject );
begin
  Self.FTaskProc := TaskProc;
  Self.FTaskParam := TaskParam;
  while not FExecuting do // Wait until Thread is executing
    Yield;

  SetEvent( Self.FTaskStartEvent ); // StartTask Task
end;

constructor TWorker.Create( Owner: TWorkerMgr; Name: string; Tag: Integer );
begin
  FName := name;
  FTag := Tag;
  FOwner := Owner;

  inherited Create( FALSE );
end;

procedure TWorker.AfterConstruction;
begin
  inherited AfterConstruction; // ResumeThread

  while not FExecuting do // Wait for thread execute
    Yield; // SuspendTask Caller's Thread, to start Worker's Thread
end;

procedure TWorker.Execute;
var
  Wait: DWORD;
  FEvents: array [ 0 .. 1 ] of THandle;
begin
  NameThreadForDebugging( FName );

  FFThreadTerminateEvent := CreateEvent( nil, True, FALSE, '' );
  FTaskStartEvent := CreateEvent( nil, True, FALSE, '' );
  FEvents[ 0 ] := FFThreadTerminateEvent;
  FEvents[ 1 ] := FTaskStartEvent;

  FTaskRunning := FALSE;
  FExecuting := True;

  try
    while not Terminated do
    begin
      Wait := WaitForMultipleObjects( 2, @FEvents, FALSE, INFINITE );
      // If more than one object became signaled during the call,
      // this is the array index of the signaled object
      // with the smallest index value of all the signaled objects.
      case Wait of
        WAIT_OBJECT_0 .. WAIT_OBJECT_0 + 1:
          if WAIT_OBJECT_0 = Wait then
          begin
            ResetEvent( FFThreadTerminateEvent );

            Exit; // Terminate Thread
          end else begin
            ResetEvent( FTaskStartEvent );

            FTaskRunning := True;

            FTaskCanceling := FALSE;
            FTaskSuspending := FALSE;

            if Assigned( FOnTaskStateChanged ) then
              FOwner.PostProcessMessage( WM_WORKER_STATE_CHANGED, NativeUInt( Self ), NativeUInt( tsStarted ) );

            FTaskResult := FTaskProc( Self, FTaskParam );

            FOwner.SendProcessMessage( WM_WORKER_STATE_CHANGED, NativeUInt( Self ), NativeUInt( tsCompleted ) );

            if FTaskCompletedEvent <> 0 then
              SetEvent( FTaskCompletedEvent );

            FTaskRunning := FALSE;
          end;

        WAIT_ABANDONED_0 .. WAIT_ABANDONED_0 + 1:
          begin
            // mutex object abandoned
          end;

        WAIT_FAILED:
          begin
            if GetLastError <> ERROR_INVALID_HANDLE then
            begin
              // the wait failed because of something other than an invalid handle
              RaiseLastOSError;
            end else begin
              // at least one handle has become invalid outside the wait call
            end;
          end;

        WAIT_TIMEOUT:
          begin
            // Never because dwMilliseconds is INFINITE
          end;
      else
        begin

        end;
      end;
    end;

  finally
    if FFThreadTerminateEvent <> 0 then
      CloseHandle( FFThreadTerminateEvent );

    if FTaskStartEvent <> 0 then
      CloseHandle( FTaskStartEvent );

    FExecuting := FALSE;
  end;
end;

procedure TWorker.QueryTaskSuspendPending;
begin
  if not FTaskSuspending then
    Exit;

  FTaskSuspending := FALSE;

  if Assigned( FOnTaskStateChanged ) then
    FOwner.PostProcessMessage( WM_WORKER_STATE_CHANGED, NativeUInt( Self ), NativeUInt( tsSuspended ) );

  FTaskSuspended := True;
  FTaskResumeEvent := CreateEvent( nil, True, FALSE, '' );

  // SuspendTask Task until ResumeTask or CancelTask by Main Thred
  WaitForSingleObject( FTaskResumeEvent, INFINITE );

  // ResumeTask Task
  ResetEvent( FTaskResumeEvent );
  CloseHandle( FTaskResumeEvent );

  if Assigned( FOnTaskStateChanged ) then
    FOwner.PostProcessMessage( WM_WORKER_STATE_CHANGED, NativeUInt( Self ), NativeUInt( tsResumed ) );
  FTaskSuspended := FALSE;
end;

function TWorker.IsTaskCancelPending: LongBool;
begin
  QueryTaskSuspendPending( );
  if FTaskCanceling then
    Exit( True )
  else
    Exit( FALSE );
end;

destructor TWorker.Destroy;
begin
  if FExecuting then
  begin
    if not FTaskRunning then // Wait for TaskStartEvent or FThreadTerminateEvent
    begin
      SetEvent( FFThreadTerminateEvent );
    end else begin
      TaskCancel;
    end;
  end;

  inherited Destroy;
end;

procedure TWorker.DoDataProcessed( WorkerDataRec: PWorkerDataRec );
begin
  if Assigned( FOnTaskDataProcessed ) then
  begin
    FOnTaskDataProcessed( Self, WorkerDataRec.Id, WorkerDataRec.DataProcessed );
  end;
end;

procedure TWorker.DoProgressChanged( ProgressChanged: Integer );
begin
  if Assigned( FOnTaskProgressChanged ) then
    FOnTaskProgressChanged( Self, ProgressChanged );
end;

procedure TWorker.DoStateChanged( CurrentState: TTaskState );
begin
  if Assigned( FOnTaskStateChanged ) then
    FOnTaskStateChanged( Self, CurrentState );

  if CurrentState = tsCompleted then
  begin
    if Self.FFreeOnTaskComplete then
      FOwner.FreeWorker( Self );
  end;
end;

{ TWorkerMgr }

procedure DeallocateHWnd( Wnd: HWND );
var
  Instance: Pointer;
begin
  Instance := Pointer( GetWindowLong( Wnd, GWL_WNDPROC ) );
  if Instance <> @DefWindowProc then
  begin
    { make sure we restore the default windows procedure before freeing memory }
    SetWindowLong( Wnd, GWL_WNDPROC, Longint( @DefWindowProc ) );
    FreeObjectInstance( Instance );
  end;
  DestroyWindow( Wnd );
end;

procedure TWorkerMgr.CreateProcessWindow;
begin
  FProcessWindow := AllocateHWnd( ProcessWndMethod );
end;

procedure TWorkerMgr.CreateThreadWindow;
begin
  FThreadWindow := AllocateHWnd( ThreadWndMethod );
end;

function TWorkerMgr.AllocWorker( Name: string; Tag: Integer ): TWorker;
var
  I: Integer;
  UnallocedWorkerFound: LongBool;
begin
  UnallocedWorkerFound := FALSE;
  for I := 0 to FWorkerList.LockList.Count - 1 do
  begin
    Result := FWorkerList.LockList[ I ];
    if not Result.FAllocedForTask then
    begin
      UnallocedWorkerFound := True;
      Break;
    end;
  end;

  if not UnallocedWorkerFound then
  begin
    if FWorkerList.LockList.Count = WORKERMGR_WORKER_MAX_NUM then
      raise EWorkerMgr.Create( 'Can not create worker thread.' );

    Result := TWorker.Create( Self, name );

    FWorkerList.Add( Result );
  end;

  Result.FName := name;
  Result.FFreeOnTaskComplete := True;
  Result.FAllocedForTask := True;

  Result.Tag := Tag;

  Result.OnTaskStateChanged := nil;
  Result.OnTaskProgressChanged := nil;
  Result.OnTaskDataProcessed := nil;
end;

procedure TWorkerMgr.FreeWorker( Worker: TWorker );
var
  I: Integer;
begin
  for I := 0 to FWorkerList.LockList.Count - 1 do
  begin
    if Worker = FWorkerList.LockList[ I ] then
    begin
      Worker.FAllocedForTask := FALSE;
      Worker := nil;
      Exit;
    end;
  end;
end;

procedure TWorkerMgr.HandleExceptionProcesshronized;
begin
  if FException is Exception then
    Application.ShowException( FException )
  else
    System.SysUtils.ShowException( FException, nil );
end;

procedure TWorkerMgr.ThreadWndMethod( var Msg: TMessage );
var
  Handled: Boolean;
  Worker: TWorker;
begin
  Handled := True; // Assume we handle message

  Worker := TWorker( Msg.WParam );

  case Msg.Msg of

    WM_TERMINATE_WORKER_MGR:
      begin
        PostQuitMessage( 0 );
      end;

  else
    Handled := FALSE; // We didn't handle message
  end;

  if Handled then // We handled message - record in message result
    Msg.Result := 0
  else // We didn't handle message, pass to DefWindowProc and record result
    Msg.Result := DefWindowProc( FProcessWindow, Msg.Msg, Msg.WParam, Msg.LParam );
end;

procedure TWorkerMgr.AfterConstruction;
begin
  inherited AfterConstruction;

  WaitForSingleObject( FReadyEvent, INFINITE );
  CloseHandle( FReadyEvent );

  if not FCreated then
    raise EWorkerMgr.Create( 'Can not create worker manager thread.' );

  FWorkerList := TThreadList< TWorker >.Create;
end;

procedure TWorkerMgr.BeforeDestruction;
begin
  if Assigned( FWorkerList ) then
  begin
    while FWorkerList.LockList.Count > 0 do
    begin
      FreeWorker( FWorkerList.LockList[ 0 ] );
      FWorkerList.LockList[ 0 ].Destroy;
      FWorkerList.Remove( FWorkerList.LockList[ 0 ] );
    end;

    FWorkerList.Free;
  end;

  inherited BeforeDestruction;
end;

constructor TWorkerMgr.Create( Name: string );
begin
  FName := name;
  FReadyEvent := CreateEvent( nil, True, FALSE, '' );
  inherited Create( FALSE );

  { Create hidden window here: store handle in FProcessWindow
    this must by synchonized because of ProcessThread Context }
  Synchronize( CreateProcessWindow );
end;

procedure TWorkerMgr.TerminatedSet;
begin
  // Exit Message Loop
  PostThreadMessage( WM_TERMINATE_WORKER_MGR, 0, 0 );
end;

procedure TWorkerMgr.DeleteProcessWindow;
begin
  if FProcessWindow <> 0 then
  begin
    DeallocateHWnd( FProcessWindow );
    FProcessWindow := 0;
  end;
end;

procedure TWorkerMgr.DeleteThreadWindow;
begin
  if FThreadWindow > 0 then
  begin
    DeallocateHWnd( FThreadWindow );
    FThreadWindow := 0;
  end;
end;

destructor TWorkerMgr.Destroy;
begin
  Terminate; // FTerminated := True;

  inherited Destroy; // WaitFor(), Destroy()

  { Destroy hidden window }
  DeleteProcessWindow( );
end;

procedure TWorkerMgr.Idle;
begin
end;

{ Run in WorkerMgr Thread }
procedure TWorkerMgr.Execute;
var
  Msg: TMsg;
begin
  NameThreadForDebugging( FName );

  FException := nil;
  try
    // Force system alloc a Message Queue for thread
    // PeekMessage( Msg, 0, WM_USER, WM_USER, PM_NOREMOVE );

    CreateThreadWindow( );
    SetEvent( FReadyEvent );

    if FThreadWindow = 0 then
      raise EWorkerMgr.Create( 'Can not create worker manager window.' );

    FCreated := True;

    try
      while not Terminated do
      begin
        if FALSE then
        begin

          if Longint( PeekMessage( Msg, 0, 0, 0, PM_REMOVE ) ) > 0 then
          begin
            // WM_QUIT Message sent by Destroy()
            if Msg.message = WM_QUIT then
              Exit;

            TranslateMessage( Msg );
            DispatchMessage( Msg );
          end else begin
            Idle;
          end;
        end else begin

          while Longint( GetMessage( Msg, 0, 0, 0 ) ) > 0 do
          begin
            TranslateMessage( Msg );
            DispatchMessage( Msg );
          end;
          // WM_QUIT Message sent by Destroy()
        end;
      end;
    finally
      DeleteThreadWindow( );
    end;

  except
    HandleException;
  end;
end;

procedure TWorkerMgr.HandleException;
begin
  FException := Exception( ExceptObject );
  try
    if FException is EAbort then // Don't show EAbort messages
      Exit;

    // Now actually show the exception in Appliction Context
    Synchronize( HandleExceptionProcesshronized );
  finally
    FException := nil;
  end;
end;

{
  SendMessage()

  Sends the specified message to a window or windows.
  The SendMessage function calls the window procedure for the specified window
  and does not return until the window procedure has processed the message.

  To send a message and return immediately,
  use the SendMessageCallback() or SendNotifyMessage() function.

  To post a message to a thread's message queue and return immediately,
  use the PostMessage() or PostThreadMessage() function.

  SendNotifyMessage()

  Sends the specified message to a window or windows.
  If the window was created by the calling thread, SendNotifyMessage calls
  the window procedure for the window and does not return
  until the window procedure has processed the message.

  If the window was created by a different thread, SendNotifyMessage passes
  the message to the window procedure and returns immediately;
  it does not wait for the window procedure to finish processing the message.

  PostMessage()

  Places (posts) a message in the message queue associated with the thread
  that created the specified window and returns without waiting
  for the thread to process the message.

  To post a message in the message queue associated with a thread,
  use the PostThreadMessage() function.

  PostThreadMessage()

  Posts a message to the message queue of the specified thread.
  It returns without waiting for the thread to process the message.
}
function TWorkerMgr.PostThreadMessage( Msg, WParam, LParam: NativeUInt ): LongBool;
begin
  while FThreadWindow = 0 do
    SwitchToThread;

  Result := Winapi.Windows.PostMessage( FThreadWindow, Msg, WParam, LParam );
end;

function TWorkerMgr.SendThreadMessage( Msg, WParam, LParam: NativeUInt ): NativeInt;
begin
  while FThreadWindow = 0 do
    SwitchToThread;

  Result := Winapi.Windows.SendMessage( FThreadWindow, Msg, WParam, LParam );
end;

function TWorkerMgr.PostProcessMessage( Msg, WParam, LParam: NativeUInt ): LongBool;
begin
  Result := Winapi.Windows.PostMessage( FProcessWindow, Msg, WParam, LParam );
end;

{ Run in Worker Thread }
function TWorkerMgr.SendProcessMessage( Msg, WParam, LParam: NativeUInt ): NativeInt;
begin
  Result := Winapi.Windows.SendMessage( FProcessWindow, Msg, WParam, LParam );
end;

{ Run in Main Thread }
procedure TWorkerMgr.ProcessWndMethod( var Msg: TMessage );
var
  Handled: Boolean;
  Worker: TWorker;
begin
  Handled := True; // Assume we handle message

  Worker := TWorker( Msg.WParam );

  case Msg.Msg of

    WM_WORKER_FEEDBACK_PROGRESS:
      begin
        Worker.DoProgressChanged( Integer( Msg.LParam ) );
      end;

    WM_WORKER_FEEDBACK_DATA:
      begin
        Worker.DoDataProcessed( PWorkerDataRec( Msg.LParam ) );
      end;

    WM_WORKER_STATE_CHANGED:
      begin
        Worker.DoStateChanged( TTaskState( Msg.LParam ) );
      end;

  else
    Handled := FALSE; // We didn't handle message
  end;

  if Handled then // We handled message - record in message result
    Msg.Result := 0
  else // We didn't handle message, pass to DefWindowProc and record result
    Msg.Result := DefWindowProc( FProcessWindow, Msg.Msg, Msg.WParam, Msg.LParam );
end;

initialization

WorkerMgr := TWorkerMgr.Create( );

finalization

WorkerMgr.Free;

end.
