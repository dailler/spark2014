package Generate_Initializes
  with Abstract_State => State
is
   A : Integer := 0;
   B : Integer;
   C : Integer;

   procedure Initialize_State
     with Global => (Output => State);
end Generate_Initializes;
