object VStarCamDownloaderService: TVStarCamDownloaderService
  OldCreateOrder = False
  AllowPause = False
  DisplayName = 'VStarCam Downloader'
  AfterInstall = ServiceAfterInstall
  BeforeUninstall = ServiceBeforeUninstall
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
