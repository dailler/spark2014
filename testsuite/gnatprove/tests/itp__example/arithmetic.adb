package body Test
is
   type Unsigned_Byte is range 0..255;
   type Byte is range -128..127;

   function Test_1 (A: Integer) return Integer
     with
       Post =>
         (for some X in Integer'Range =>
          5 * X = 0)
   is
   begin
      return A;
   end Test_1;

end Test;
