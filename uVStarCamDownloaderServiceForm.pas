Unit uVStarCamDownloaderServiceForm;

Interface

Uses Vcl.SvcMgr, uVStarCamDownloader;

Type
  TVStarCamDownloaderService = Class(TService)
    Procedure ServiceAfterInstall(Sender: TService);
    Procedure ServiceBeforeUninstall(Sender: TService);
    Procedure ServiceStart(Sender: TService; Var Started: Boolean);
    Procedure ServiceStop(Sender: TService; Var Stopped: Boolean);
    Procedure ServiceShutdown(Sender: TService);
  strict private
    _logfile: TextFile;
    _downloader: TVStarCamDownloader;
    Procedure Log(inString: String);
  public
    Function GetServiceController: TServiceController; Override;
  End;

Var
  VStarCamDownloaderService: TVStarCamDownloaderService;

Implementation

Uses WinApi.Windows, System.SysUtils, Registry, WinApi.WinSvc, Vcl.Dialogs, System.UITypes;

{$I-}
{$R *.dfm}

Procedure ServiceController(CtrlCode: DWord); Stdcall;
Begin
  VStarCamDownloaderService.Controller(CtrlCode);
End;

Function TVStarCamDownloaderService.GetServiceController: TServiceController;
Begin
  Result := ServiceController;
End;

Procedure TVStarCamDownloaderService.Log(inString: String);
Var
  shouldrotate: Boolean;
  rotatelogname: String;
Begin
  TMonitor.Enter(Self);
  Try
    Append(_logfile);
    If IOResult <> 0 Then
      ReWrite(_logfile);
    Try
      WriteLn(_logfile, inString);

      // We'll rotate the log file at ~1,9 GB, otherwise it'll crash the application on 32 bit systems
      shouldrotate := FileSize(_logfile) * 128 >= 2000000000;
    Finally
      CloseFile(_logfile);
    End;

    If shouldrotate Then
    Begin
      rotatelogname := ExtractFileName(ParamStr(0));
      Insert('-', rotatelogname, rotatelogname.Length - 4);
      rotatelogname := ChangeFileExt(rotatelogname, '.log');
      If Not RenameFile(ChangeFileExt(ParamStr(0), '.log'), rotatelogname) Then
        RaiseLastOSError;
    End;
  Finally
    TMonitor.Exit(Self);
  End;
End;

Procedure TVStarCamDownloaderService.ServiceAfterInstall(Sender: TService);
Var
  reg: TRegistry;
Begin
  reg := TRegistry.Create(KEY_READ Or KEY_WRITE);
  Try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    If reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + Name, False) Then
    Begin
      reg.WriteString('Description', 'Downloads recordings from VStarCam devices when SD card is full.');
      reg.CloseKey;
    End;
  Finally
    FreeAndNil(reg);
  End;
End;

Procedure TVStarCamDownloaderService.ServiceBeforeUninstall(Sender: TService);
Var
  schm, schs: SC_Handle;
  ss: TServiceStatus;
Begin
  If Not FindCmdLineSwitch('silent', True) And (MessageDlg('Are you sure you want to uninstall?', mtConfirmation, [mbYes, mbNo], 0) = mrNo) Then
    Halt(0);

  schm := OpenSCManager('', nil, SC_MANAGER_CONNECT);
  If schm > 0 Then
  Try
    schs := OpenService(schm, PChar(Name), SERVICE_STOP Or SERVICE_QUERY_STATUS);
    If schs > 0 Then
    Try
      ControlService(schs, SERVICE_CONTROL_STOP, ss);
    Finally
      CloseServiceHandle(schs);
    End;
  Finally
    CloseServiceHandle(schm);
  End;
End;

Procedure TVStarCamDownloaderService.ServiceShutdown(Sender: TService);
Begin
  FreeAndNil(_downloader);
End;

Procedure TVStarCamDownloaderService.ServiceStart(Sender: TService; Var Started: Boolean);
Begin
  AssignFile(_logfile, ChangeFileExt(ParamStr(0), '.log'));
  _downloader := TVStarCamDownloader.Create(Log);
End;

Procedure TVStarCamDownloaderService.ServiceStop(Sender: TService; Var Stopped: Boolean);
Begin
  FreeAndNil(_downloader);
End;

End.
