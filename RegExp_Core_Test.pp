program RegExp_Core_Test;

{$ASSERTIONS ON}

uses
  SysUtils, RegExp_Core;

var
  Text: PWideChar;
  SearchText: PWideChar;
  Sequence: TCharsetSequence;
  StartTick: Int64;
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
end.