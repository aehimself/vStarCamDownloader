Program VStarCamDownloader;

uses
  Vcl.SvcMgr,
  System.SysUtils,
  uVStarCamDownloaderServiceForm in 'uVStarCamDownloaderServiceForm.pas' {VStarCamDownloaderService: TService},
  uVStarCamDownloader in 'uVStarCamDownloader.pas',
  uDownloaderEngine in 'uDownloaderEngine.pas',
  uSettings in 'uSettings.pas',
  AE.Application.Console;

{$R *.RES}

Begin
 If Not FindCmdLineSwitch('console', True) Then
 Begin
   If Not Application.DelayInitialize Or Application.Installing Then
     Application.Initialize;
   Application.CreateForm(TVStarCamDownloaderService, VStarCamDownloaderService);
  Application.Run;
 End
 Else
   StartWithConsole(TVStarCamDownloader);
End.
