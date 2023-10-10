{
  VStarcamDownloader © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit uDownloaderEngine;

Interface

Uses AE.Application.Engine, System.Net.HTTPClientComponent, System.Net.URLClient, System.Net.HttpClient, System.SysUtils;

Type
  TSDCardStatus = (sdNotPresent, sdIdle, sdRecording, sdFileSystemError, sdFormatting, sdCantMount);

  TAuthMode = (amNone, amURL, amHeader);

  TDownloaderEngine = Class(TAEApplicationEngine)
  strict private
    _authheader: TNameValuePair;
    _cameraname: String;
    _cameratime: TDateTime;
    _httpclient: TNetHTTPClient;
    _lasttimecheck: TDateTime;
    _sdstatus: TSDCardStatus;
    _settingscameraname: String;
    Function HTTPGet(inURL: String; Const inAuthMode: TAuthMode = amURL): IHTTPResponse;
    Function CameraName: String;
    Function DownloadFolder: String;
    Function DownloadSpeed(Const inSizeInBytes, inTimeInMilliseconds: UInt64): String;
    Function EnableRecord(Const inRecordEnabled: Boolean): Boolean;
    Function FormatSDCard: Boolean;
    Function GetFileNames: TArray<String>;
    Function SuccessfulHTTP(Const inResponse: IHTTPResponse; Const inAction: String): Boolean;
    Function UpdateCameraInfo(Const inLogInfo: Boolean = True): Boolean;
  strict protected
    Procedure BeforeWork; Override;
    Procedure WorkCycle; Override;
    Procedure Creating; Override;
    Procedure Destroying; Override;
    Procedure Log(inString: String); Override;
  public
    Procedure SetCameraName(Const inCameraSettingsName: String);
  End;

Implementation

// Play: "C:\Program Files\VideoLAN\VLC\vlc.exe" --demux=h264 -vvv 20210627173932_010.h26
// Convert: C:\Users\aehim>"C:\Program Files\VideoLAN\VLC\vlc.exe" -I dummy --demux=h264 -vvv 20210627173932_010.h26 --sout=#transcode{vcodec=h264,vb=1024}:standard{access=file,mux=ts,dst=MyVid.mp4} vlc://quit

Uses System.Generics.Collections, System.Diagnostics, uSettings, System.DateUtils, System.IOUtils, System.NetEncoding, AE.Misc.UnixTimestamp;

Procedure TDownloaderEngine.BeforeWork;
Begin
  inherited;

  // Create the authorization header which is required to download recorded files
  _authheader.Name := 'Authorization';
  _authheader.Value := 'Basic ' + TNetEncoding.Base64.Encode('admin:' + Settings.Camera[_settingscameraname].Password);
End;

Function TDownloaderEngine.CameraName: String;
Begin
  If _cameraname.IsEmpty Then
    Result := _settingscameraname
  Else
    Result := _cameraname;
End;

Procedure TDownloaderEngine.Creating;
Begin
  inherited;

  _httpclient := TNetHTTPClient.Create(nil);

  _cameraname := '';
  _cameratime := 0;
  _lasttimecheck := 0;
  _sdstatus := sdNotPresent;
  _settingscameraname := '';
End;

Procedure TDownloaderEngine.Destroying;
Begin
  FreeAndNil(_httpclient);

  inherited;
End;

Function TDownloaderEngine.DownloadFolder: String;
Begin
  // Helper to assemble the folder name where THIS engine is going to place recordings

  Result := IncludeTrailingPathDelimiter(Settings.DownloadLocation) + Self.CameraName;
End;

Function TDownloaderEngine.DownloadSpeed(Const inSizeInBytes, inTimeInMilliseconds: UInt64): String;
Begin
  // Calculate the transfer speed from file size and time spent and format it

  If inSizeInBytes >= 1073741824 Then
    Result := FormatFloat('0.#', inSizeInBytes / 1073741824 / inTimeInMilliseconds * 1000) + ' GB/s'
  Else If inSizeInBytes >= 1048576 Then
    Result := FormatFloat('0.#', inSizeInBytes / 1048576 / inTimeInMilliseconds * 1000) + ' MB/s'
  Else If inSizeInBytes >= 1024 Then
    Result := FormatFloat('0.#', inSizeInBytes / 1024 / inTimeInMilliseconds * 1000) + ' kb/s'
  Else
    Result := FormatFloat('0.#', inSizeInBytes / inTimeInMilliseconds * 1000) + ' b/s'
End;

Function TDownloaderEngine.EnableRecord(Const inRecordEnabled: Boolean): Boolean;
Var
  response: IHTTPResponse;
  urlbool, logbool: String;
Begin
  // Enable or disable SD card recording

  If inRecordEnabled Then
  Begin
    urlbool := '1';
    logbool := 'enable';
  End
  Else
  Begin
    urlbool := '0';
    logbool := 'disable';
  End;

  Log(logbool + ' SD card recording...');
  response := HTTPGet('set_alarm.cgi?record=' + urlbool);
  Result := SuccessfulHTTP(response, logbool + ' SD card recording');

  If Not Result Then
    Exit;

  // When disabling recording, wait for the currect recording to stop before returning, otherwise we might corrupt the downloaded data
  If Not inRecordEnabled Then
    While _sdstatus <> sdIdle Do
    Begin
      If Self.Terminated Then
        Abort;
      Sleep(1000);
      Self.UpdateCameraInfo(False);
    End;

  Log(logbool + ' SD card recording successful.');
End;

Function TDownloaderEngine.FormatSDCard: Boolean;
Var
  response: IHTTPResponse;
Begin
  // Format the SD card, removing all files on it

  Log('Starting to format SD card...');
  response := HTTPGet('set_formatsd.cgi');
  Result := SuccessfulHTTP(response, 'format SD card');

  If Not Result Then
    Exit;

  Sleep(1000);

  Self.UpdateCameraInfo(False);
  While _sdstatus = sdFormatting Do
  Begin
    If Self.Terminated Then
      Abort;
    Sleep(1000);
    Self.UpdateCameraInfo(False);
  End;

  Log('SD card formatted successfully.');
End;

Function TDownloaderEngine.GetFileNames: TArray<String>;
Var
  response: IHTTPResponse;
  filelist: TList<String>;
  s: String;
Begin
  // List all files on the SD card which has to be downloaded

  Log('Starting to download recorded file list...');

  filelist := TList<String>.Create;
  Try
    response := HTTPGet('get_record_file.cgi?PageSize=10000');

    If Not SuccessfulHTTP(response, 'get recorded file list') Then
      Exit;

    For s In response.ContentAsString.Split([sLineBreak]) Do
      If s.StartsWith('record_name0[') Then
        filelist.Add(s.Substring(s.IndexOf('"') + 1, s.Length - s.IndexOf('"') - 4));

    Log('File list downladed successfully.');
  Finally
    Result := filelist.ToArray;
    filelist.Free;
  End;
End;

Function TDownloaderEngine.HTTPGet(inURL: String; Const inAuthMode: TAuthMode = amURL): IHTTPResponse;
Var
  failcount: Integer;
  headers: TNetHeaders;
Begin
  inURL := 'http://' + Settings.Camera[_settingscameraname].Hostname + '/' + inURL;

  Case inAuthMode Of
    amNone:
      headers := [];
    amURL:
    Begin
      headers := [];

      If inURL.Contains('?') Then
        inURL := inURL + '&'
      Else
        inURL := inURL + '?';

      inURL := inURL + 'loginuse=admin&loginpas=' + Settings.Camera[_settingscameraname].Password;
    End;
    amHeader:
      headers := [_authheader];
  End;

  // Perform the HTTP GET command. Retry 4 times with a 3 second delay before considering it failed.
  failcount := 0;

  Repeat
    Try
      Result := _httpclient.Get(inURL, nil, headers);

      Exit;
    Except
      On E:Exception Do
      Begin
        If failcount = 4 Then
          Raise;

        HandleException(E, '#' + failcount.ToString + ' getting URL ' + inURL);
        Inc(failcount);
        Sleep(3000);
      End;
    End;
  Until False;
End;

Procedure TDownloaderEngine.Log(inString: String);
Begin
  inherited Log(Self.CameraName + ' ' + inString);
End;

Procedure TDownloaderEngine.SetCameraName(Const inCameraSettingsName: String);
Begin
  _settingscameraname := inCameraSettingsName;
End;

Function TDownloaderEngine.SuccessfulHTTP(Const inResponse: IHTTPResponse; Const inAction: String): Boolean;
Begin
  // Helper to determine if a HTTP call was successful or not. Also put the entries in the log

  Result := Assigned(inResponse) And (inResponse.StatusCode = 200);

  If Not Assigned(inResponse) Then
    Log('Could not ' + inAction + ', no response from camera');
  If inResponse.StatusCode <> 200 Then
    Log('Could not ' + inAction + ', camera reported: ' + inResponse.StatusCode.ToString + ' ' + inResponse.StatusText);
End;

Function TDownloaderEngine.UpdateCameraInfo(Const inLogInfo: Boolean = True): Boolean;
Var
  response: IHTTPResponse;
  s, key, value: String;
  sdsize, sdfree: Word;
Begin
  Result := False;

  If inLogInfo Then
    Log('Attempting to download camera information...');

  _cameraname := '';
  _sdstatus := sdNotPresent;
  response := HTTPGet('get_status.cgi');

  If Not SuccessfulHTTP(response, 'get camera information') Then
    Exit;

  For s In response.ContentAsString.Split([sLineBreak]) Do
  Begin
    key := s.Substring(0, s.IndexOf('=')).Replace('var ', '');
    value := s.Substring(s.IndexOf('=') + 1, s.Length - s.IndexOf('=') - 2);
    If key = 'alias' Then
      _cameraname := value.Substring(1, value.Length - 2)
    Else If key = 'sdtotal' Then
      sdsize := Word.Parse(value)
    Else If key = 'sdfree' Then
      sdfree := Word.Parse(value)
    Else If key = 'sdstatus' Then
      _sdstatus := TSDCardStatus(Integer.Parse(value))
    Else If key = 'now' Then
      _cameratime := UnixToDate(UInt64.Parse(value));
  End;

  Result := True;

  If Not inLogInfo Then
    Exit;

  s := Self.CameraName + ' SD card ';
  Case _sdstatus Of
    sdIdle, sdRecording:
      Begin
        If _sdstatus = sdIdle Then
          s := s + 'idle'
        Else
          s := s + 'recording';

        s := s + ' ' + sdfree.ToString + ' MB / ' + sdsize.ToString + ' MB free (' + FormatFloat('0.##', sdfree * 100 / sdsize) + '%)';
      End;
    sdNotPresent:
      s := s + 'not present';
    sdFileSystemError:
      s := s + 'file system error';
    sdFormatting:
      s := s + 'formatting';
    sdCantMount:
      s := s + 'cannot be mounted';
  End;

  Log(s);
End;

Procedure TDownloaderEngine.WorkCycle;
Var
  s: String;
  filelist: TArray<String>;
  count: Integer;
  response: IHTTPResponse;
  stopwatch: TStopWatch;
  buffer: TBytes;
  loctime: TDateTime;
Begin
  inherited;

  // Check and attempt to fix camera's time every 30 minutes
  loctime := Now;
  If MinutesBetween(loctime, _lasttimecheck) >= 30 Then
  Begin
    Self.UpdateCameraInfo(False);

    If MinutesBetween(loctime, _cameratime) >= 5 Then
    Begin
      response := HTTPGet('set_datetime.cgi?now=' + DateToUnix(loctime).ToString);

      If SuccessfulHTTP(response, 'set time') Then
        Self.Log('Camera time was off and has been fixed. Camera time: ' + FormatDateTime('yyyy.mm.dd hh:nn:ss', _cameratime) + ', local time: ' + FormatDateTime('yyyy.mm.dd hh:nn:ss', loctime) + ', ' + SecondsBetween(_cameratime, loctime).ToString + ' seconds of difference.');
    End;

    _lasttimecheck := loctime;
  End;

  // Download once every 24 hours
  If DaysBetween(Now, Settings.Camera[_settingscameraname].LastDownload) < 1 Then
    Exit;

  Self.UpdateCameraInfo;

  filelist := Self.GetFileNames;

  If Length(filelist) = 0 Then
  Begin
    Log('There are no files to be downloaded at this time.');
    Settings.Camera[_settingscameraname].LastDownload := Now;
    Exit;
  End;

  If Not EnableRecord(False) Then
    Exit;

  Try
    count := 0;

    For s In filelist Do
    Begin
      If Not TDirectory.Exists(Self.DownloadFolder) Then
        TDirectory.CreateDirectory(Self.DownloadFolder);

      Inc(count);
      If Not TFile.Exists(Self.DownloadFolder + '\' + s) Then
      Begin
        Log('Downloading file ' + count.ToString + '/' + Length(filelist).ToString + ': ' + s);

        stopwatch := TStopWatch.StartNew;
        response := HTTPGet('record/' + s, amHeader);
        stopwatch.Stop;

        If Not SuccessfulHTTP(response, 'download file') Or (response.ContentLength <= 0) Then
          Continue;

        SetLength(buffer, response.ContentLength);
        response.ContentStream.Read(buffer, Length(buffer));
        TFile.WriteAllBytes(Self.DownloadFolder + '\' + s, buffer);
        Log(response.ContentLength.ToString + ' bytes were downloaded in ' + Integer(stopwatch.ElapsedMilliseconds Div 1000).ToString + ' seconds. Transfer speed was ' + DownloadSpeed(response.ContentLength, stopwatch.ElapsedMilliseconds));
      End
      Else
        Log(s + ' is not going to be downloaded as it already seems to exist');

      If Self.Terminated Then
        Exit;
    End;

    If FormatSDCard Then
      Settings.Camera[_settingscameraname].LastDownload := Now;
  Finally
    EnableRecord(True);
  End;
End;

End.
