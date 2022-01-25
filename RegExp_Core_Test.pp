program RegExp_Core_Test;

{$ASSERTIONS ON}
// {$DEFINE BENCHMARK}

uses
  SysUtils, RegExp_Core;

var
  Text: PWideChar;
  SearchText: PWideChar;
  Sequence: TCharGroupSequence;
  StartTick: Int64;
  I: LongWord;
begin
  Text := 'Hello World';

  // Scan for `Hello` in `Hello World`
  SearchText := 'Hello';
  Sequence := StringToSequence(SearchText);
  Assert(ScanSequence(Text, 0, Sequence));

  // Scan for `hello` in `Hello World`
  SearchText := 'hello';
  Sequence := StringToSequence(SearchText);
  Assert(not ScanSequence(Text, 0, Sequence));

  // Scan for `World` in `Hello World`
  SearchText := 'World';
  Sequence := StringToSequence(SearchText);
  Assert(ScanSequence(Text, 0, Sequence));

  {$IFDEF BENCHMARK}
  StartTick := GetTickCount64();
  for I := 1 to 1000000 do
    Assert(ScanSequence(Text, 0, Sequence));
  WriteLn(Format('Done in %d ms', [ GetTickCount64() - StartTick]));
  {$ENDIF}
end.