Program VStarCamDownloader;

uses
  Vcl.SvcMgr,
  System.SysUtils,
  uVStarCamDownloaderServiceForm in 'uVStarCamDownloaderServiceForm.pas' {VStarCamDownloaderService: TService},
  uVStarCamDownloader in 'uVStarCamDownloader.pas',
  uDownloaderEngine in 'uDownloaderEngine.pas',
  uSettings in 'uSettings.pas',
  AE.Application.Engine in '..\_DelphiComponents\AEFramework\AE.Application.Engine.pas',
  AE.Application.Helper in '..\_DelphiComponents\AEFramework\AE.Application.Helper.pas',
  AE.Application.Settings in '..\_DelphiComponents\AEFramework\AE.Application.Settings.pas',
  AE.Application.Application in '..\_DelphiComponents\AEFramework\AE.Application.Application.pas',
  AE.Application.Console in '..\_DelphiComponents\AEFramework\AE.Application.Console.pas';

{$R *.RES}

Begin
 If Not FindCmdLineSwitch('console', True) Then Begin
                                                If Not Application.DelayInitialize Or Application.Installing Then Application.Initialize;
                                                Application.CreateForm(TVStarCamDownloaderService, VStarCamDownloaderService);
                                                Application.Run;
                                                End
   Else StartWithConsole(TVStarCamDownloader);
End.
