package body Ring_Buf is

   procedure Clear (R : in out Ring_Buffer) is
   begin
      R.Length := 0;
   end Clear;

   procedure Push (R : in out Ring_Buffer; X : Integer)
   is
   begin
      R.Data ((R.First + R.Length) mod Buf_Size) := X;
      R.Length := R.Length + 1;
   end Push;

   procedure Pop (R : in out Ring_Buffer; Element : out Integer)
   is
   begin
      Element := R.Data (R.First);
      R.First := (R.First + 1) mod Buf_Size;
      R.Length := R.Length - 1;
   end Pop;

end Ring_Buf;
