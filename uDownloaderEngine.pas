{
  VStarcamDownloader © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit uDownloaderEngine;

Interface

Uses AE.Application.Engine, System.Net.HTTPClientComponent, System.Net.URLClient, System.Net.HttpClient, System.SysUtils, System.Classes, uSettings;

Type
  TAuthMode = (amNone, amURL, amHeader);

  TDownloaderEngine = Class(TAEApplicationEngine)
  strict private
    _authheader: TNameValuePair;
    _camera: TCamera;
    _cameraname: String;
    _cameratime: TDateTime;
    _httpclient: TNetHTTPClient;
    _lastwork: TDateTime;
    _sdfreepercent: Single;
    Procedure SanitizeKeyValue(Var inValue: String);
    Function HTTPGet(inURL: String; Const inAuthMode: TAuthMode = amURL): IHTTPResponse;
    Function CameraName: String;
    Function DownloadFolder: String;
    Function DownloadSpeed(Const inSizeInBytes, inTimeInMilliseconds: UInt64): String;
    Function GetFileNames: TArray<String>;
    Function GetKeyValue(Const inResponse: IHTTPResponse; Const inKey: String): String; Overload;
    Function GetKeyValue(Const inStringList: TStringList; Const inKey: String): String; Overload;
    Function SizeToText(Const inNumber: UInt64): String;
    Function SuccessfulHTTP(Const inResponse: IHTTPResponse; Const inAction: String): Boolean;
    Function UpdateCameraInfo: String;
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
// Convert: "C:\Program Files\VideoLAN\VLC\vlc.exe" -I dummy --demux=h264 -vvv 20210627173932_010.h26 --sout=#transcode{vcodec=h264,vb=1024}:standard{access=file,mux=ts,dst=MyVid.mp4} vlc://quit

Uses System.Generics.Collections, System.Diagnostics, System.DateUtils, System.IOUtils, System.NetEncoding, AE.Misc.UnixTimestamp;

Const
  GBDIV = 1073741824; // 1024 * 1024 * 1024
  MBDIV = 1048576;    // 1024 * 1024
  KBDIV = 1024;

Procedure TDownloaderEngine.BeforeWork;
Begin
  inherited;

  // Create the authorization header which is required to download recorded files
  _authheader.Name := 'Authorization';
  _authheader.Value := 'Basic ' + TNetEncoding.Base64.Encode(_camera.UserName + ':' + _camera.Password);
End;

Function TDownloaderEngine.CameraName: String;
Begin
  If _cameraname.IsEmpty Then
    Result := _camera.Hostname
  Else
    Result := _cameraname;
End;

Procedure TDownloaderEngine.Creating;
Begin
  inherited;

  _httpclient := TNetHTTPClient.Create(nil);

  _cameraname := '';
  _cameratime := 0;
  _lastwork := 0;
  _sdfreepercent := 0;
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

  If inSizeInBytes >= GBDIV Then
    Result := FormatFloat('0.#', inSizeInBytes / GBDIV / inTimeInMilliseconds * 1000) + ' GB/s'
  Else If inSizeInBytes >= MBDIV Then
    Result := FormatFloat('0.#', inSizeInBytes / MBDIV / inTimeInMilliseconds * 1000) + ' MB/s'
  Else If inSizeInBytes >= KBDIV Then
    Result := FormatFloat('0.#', inSizeInBytes / KBDIV / inTimeInMilliseconds * 1000) + ' kb/s'
  Else
    Result := FormatFloat('0.#', inSizeInBytes / inTimeInMilliseconds * 1000) + ' b/s'
End;

Function TDownloaderEngine.GetFileNames: TArray<String>;
Var
  response: IHTTPResponse;
  s: String;
  sl: TStringList;
  a: Integer;
Begin
  // List all files on the SD card which has to be downloaded

  Log('Starting to download recorded file list...');

  sl := TStringList.Create;
  Try
    response := HTTPGet('get_record_file.cgi?PageSize=10000');

    If Not SuccessfulHTTP(response, 'get recorded file list') Then
      Exit;

    sl.Text := response.ContentAsString;

    s := GetKeyValue(sl, 'var record_num0');
    If Not s.IsEmpty Then
    Begin
      SetLength(Result, Integer.Parse(s));

      For a := Low(Result) To High(Result) Do
        Result[a] := GetKeyValue(sl, 'record_name0[' + a.ToString + ']');
    End;

    Log('File list downladed successfully.');
  Finally
    sl.Free;
  End;
End;

Function TDownloaderEngine.GetKeyValue(Const inStringList: TStringList; Const inKey: String): String;
Begin
  Result := inStringList.Values[inKey];

  SanitizeKeyValue(Result);
End;

Function TDownloaderEngine.GetKeyValue(Const inResponse: IHTTPResponse; Const inKey: String): String;
Var
  index: Integer;
Begin
  Result := '';

  index := inResponse.ContentAsString.IndexOf(inKey + '=');
  If index = -1 Then
    Exit;

  Begin
    Inc(index, inKey.Length + 1);

    Result := inResponse.ContentAsString.Substring(index, inResponse.ContentAsString.IndexOf(sLineBreak, index) - index);

    SanitizeKeyValue(Result);
  End;
End;

Function TDownloaderEngine.HTTPGet(inURL: String; Const inAuthMode: TAuthMode = amURL): IHTTPResponse;
Var
  failcount: Integer;
  headers: TNetHeaders;
Begin
  inURL := 'http://' + _camera.Hostname + '/' + inURL;

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

      inURL := inURL + 'loginuse=' + TNetEncoding.URL.Encode(_camera.UserName) + '&loginpas=' + TNetEncoding.URL.Encode(_camera.Password);
    End;
    amHeader:
      headers := [_authheader];
  End;

  // Perform the HTTP GET command. Retry 4 times with a 3 second delay before considering it failed.
  failcount := 0;

  Repeat
    Result := nil;

    If Self.Terminated Then
      Exit;

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

Procedure TDownloaderEngine.SanitizeKeyValue(Var inValue: String);
Begin
  If inValue.EndsWith(';') Then
    inValue := inValue.Substring(0, inValue.Length - 1);

  If inValue.StartsWith('"') And inValue.EndsWith('"') Then
    inValue := inValue.Substring(1, inValue.Length - 2);
End;

Procedure TDownloaderEngine.SetCameraName(Const inCameraSettingsName: String);
Begin
  _camera := Settings.Camera[inCameraSettingsName];
End;

Function TDownloaderEngine.SizeToText(Const inNumber: UInt64): String;
Begin
  If inNumber >= GBDIV Then
    Result := FormatFloat('0.### GB', inNumber / GBDIV)
  Else If inNumber >= MBDIV Then
    Result := FormatFloat('0.### Mb', inNumber / MBDIV)
  Else If inNumber >= KBDIV Then
    Result := FormatFloat('0.### kB', inNumber / KBDIV)
  Else
    Result := inNumber.ToString + ' byte(s)';
End;

Function TDownloaderEngine.SuccessfulHTTP(Const inResponse: IHTTPResponse; Const inAction: String): Boolean;
Var
  s: String;
Begin
  // Helper to determine if a HTTP call was successful or not. Also put the entries in the log

  Result := Assigned(inResponse) And (inResponse.StatusCode = 200);

  If Not Assigned(inResponse) Then
    Log('Could not ' + inAction + ', no response from camera');

  If inResponse.StatusCode <> 200 Then
    Log('Could not ' + inAction + ', camera reported: ' + inResponse.StatusCode.ToString + ' ' + inResponse.StatusText);

  // Binary downloads are sent with the MIME type text/plain (?????) but everything else is text/html
  If inResponse.MimeType <> 'text/html' Then
    Exit;

  s := GetKeyValue(inResponse, 'var result');
  If Not s.IsEmpty Then
  Begin
    Result := s = 'ok';

    If Not Result Then
      Log('Could not ' + inAction + ', camera result: ' + s);
  End;
End;

Function TDownloaderEngine.UpdateCameraInfo: String;
Var
  response: IHTTPResponse;
  sdsize, sdfree: UInt64;
  sl: TStringList;
Begin
  Result := '';

  _cameraname := '';
  response := HTTPGet('get_status.cgi');

  If Not SuccessfulHTTP(response, 'get camera information') Then
    Exit;

  sl := TStringList.Create;
  Try
    sl.Text := response.ContentAsString;

    _cameraname := GetKeyValue(sl, 'var alias');
    sdsize := UInt64.Parse(GetKeyValue(sl, 'var sdtotal')) * MBDIV;
    sdfree := UInt64.Parse(GetKeyValue(sl, 'var sdfree')) * MBDIV;
    _cameratime := UnixToDate(UInt64.Parse(GetKeyValue(sl, 'var now')));

    If sdsize = 0 Then
      _sdfreepercent := -1
    Else
      _sdfreepercent := sdfree * 100 / sdsize;
  Finally
    sl.Free;
  End;

  If sdsize <> 0 Then
    Result := Self.CameraName + ' SD card ' + SizeToText(sdfree) + ' / ' + SizeToText(sdsize) + ' free (' + FormatFloat('0.##', _sdfreepercent) + '%)'
  Else
    Result := Self.CameraName + ' SD card not present or faulty';
End;

Procedure TDownloaderEngine.WorkCycle;
Var
  s: String;
  filelist: TArray<String>;
  count: Integer;
  response: IHTTPResponse;
  stopwatch: TStopWatch;
Begin
  inherited;

  If Self.Terminated Then
    Exit;

  If MinutesBetween(Now, _lastwork) < 10 Then
    Exit;

  s := Self.UpdateCameraInfo;

  _lastwork := Now;

  // Check and attempt to fix camera's time every 30 minutes
  If MinutesBetween(_lastwork, _cameratime) >= 5 Then
  Begin
    response := HTTPGet('set_datetime.cgi?now=' + DateToUnix(_lastwork).ToString);

    If SuccessfulHTTP(response, 'set time') Then
      Self.Log('Camera time was off and has been readjusted. Camera time: ' + FormatDateTime('yyyy.mm.dd hh:nn:ss', _cameratime) + ', local time: ' + FormatDateTime('yyyy.mm.dd hh:nn:ss', _lastwork) + '.');
  End;

  // Start downloading if the SD card is present and has less than 50% free space
  If (_sdfreepercent < 0) Or (_sdfreepercent > 50) Then
    Exit;

  Log(s);

  // Get the list of files on the SD card
  filelist := Self.GetFileNames;

  If Length(filelist) = 0 Then
  Begin
    Log('There are no files to be downloaded at this time.');

    Exit;
  End;

  count := 0;

  If Not TDirectory.Exists(Self.DownloadFolder) Then
    TDirectory.CreateDirectory(Self.DownloadFolder);

  For s In filelist Do
  Begin
    If Self.Terminated Then
      Exit;

    Inc(count);
    If Not TFile.Exists(Self.DownloadFolder + '\' + s) Then
    Begin
      Log('Downloading file ' + count.ToString + '/' + Length(filelist).ToString + ': ' + s);

      // Actually download the file
      stopwatch := TStopWatch.StartNew;
      response := HTTPGet('record/' + TNetEncoding.URL.Encode(s), amHeader);
      stopwatch.Stop;

      If Not SuccessfulHTTP(response, 'download file') Or (response.ContentLength <= 0) Then
        Continue;

      (Response.ContentStream As TMemoryStream).SaveToFile(Self.DownloadFolder + '\' + s);
      Log(SizeToText(response.ContentLength) + ' downloaded in ' + Integer(stopwatch.ElapsedMilliseconds Div 1000).ToString + ' seconds. Transfer speed was ' + DownloadSpeed(response.ContentLength, stopwatch.ElapsedMilliseconds));
    End
    Else
      Log(s + ' is not going to be downloaded as it already seems to exist');

    // After downloading, delete this file from the camera
    SuccessfulHTTP(HTTPGet('del_file.cgi?name=' + TNetEncoding.URL.Encode(s)), 'delete file');
  End;
End;

End.
