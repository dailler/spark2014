------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                   G N A T 2 W H Y - S U B P R O G R A M S                --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                       Copyright (C) 2010-2012, AdaCore                   --
--                                                                          --
-- gnat2why is  free  software;  you can redistribute  it and/or  modify it --
-- under terms of the  GNU General Public License as published  by the Free --
-- Software  Foundation;  either version 3,  or (at your option)  any later --
-- version.  gnat2why is distributed  in the hope that  it will be  useful, --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public License  distributed with  gnat2why;  see file COPYING3. --
-- If not,  go to  http://www.gnu.org/licenses  for a complete  copy of the --
-- license.                                                                 --
--                                                                          --
-- gnat2why is maintained by AdaCore (http://www.adacore.com)               --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Containers.Doubly_Linked_Lists;

with Alfa;                  use Alfa;
with Alfa.Definition;       use Alfa.Definition;
with Alfa.Frame_Conditions; use Alfa.Frame_Conditions;

with Atree;                 use Atree;
with Einfo;                 use Einfo;
with Namet;                 use Namet;
with Nlists;                use Nlists;
with Sem_Util;              use Sem_Util;
with Sinfo;                 use Sinfo;
with Snames;                use Snames;
with Stand;                 use Stand;
with String_Utils;          use String_Utils;
with VC_Kinds;              use VC_Kinds;

with Why;                   use Why;
with Why.Atree.Accessors;   use Why.Atree.Accessors;
with Why.Atree.Builders;    use Why.Atree.Builders;
with Why.Atree.Mutators;    use Why.Atree.Mutators;
with Why.Gen.Binders;       use Why.Gen.Binders;
with Why.Gen.Decl;          use Why.Gen.Decl;
with Why.Gen.Expr;          use Why.Gen.Expr;
with Why.Gen.Names;         use Why.Gen.Names;
with Why.Gen.Progs;         use Why.Gen.Progs;
with Why.Conversions;       use Why.Conversions;
with Why.Sinfo;             use Why.Sinfo;
with Why.Types;             use Why.Types;

with Gnat2Why.Decls;        use Gnat2Why.Decls;
with Gnat2Why.Driver;       use Gnat2Why.Driver;
with Gnat2Why.Expr;         use Gnat2Why.Expr;
with Gnat2Why.Nodes;        use Gnat2Why.Nodes;
with Gnat2Why.Types;        use Gnat2Why.Types;

package body Gnat2Why.Subprograms is

   ---------------------
   -- Local Variables --
   ---------------------

   --  Expressions X'Old and F'Result are normally expanded into references to
   --  saved values of variables by the frontend, but this expansion does not
   --  apply to the original postcondition. It is this postcondition which
   --  is translated by gnat2why into a program to detect possible run-time
   --  errors, therefore a special mechanism is needed to deal with expressions
   --  X'Old and F'Result.

   Result_Name : W_Identifier_Id := Why_Empty;
   --  Name to use for occurrences of F'Result in the postcondition. It should
   --  be equal to Why_Empty when we are not generating code for detecting
   --  run-time errors in the postcondition.

   type Old_Node is record
      Ada_Node : Node_Id;
      Why_Name : Name_Id;
   end record;
   --  Ada_Node is an expression whose 'Old attribute is used in a
   --  postcondition. Why_Name is the name to use for Ada_Node'Old in Why.

   package Old_Nodes is new Ada.Containers.Doubly_Linked_Lists (Old_Node);

   Old_List : Old_Nodes.List;
   --  List of all expressions whose 'Old attribute is used in the current
   --  postcondition, together with the translation of the corresponding
   --  expression in Why. Until 'Old is forbidden in the body, this is also
   --  used to translate occurrences of 'Old that are left by the frontend (for
   --  example, inside quantified expressions that are only preanalyzed).
   --
   --  The list is cleared before generating Why code for VC generation for the
   --  body and postcondition, filled during the translation, and used
   --  afterwards to generate the necessary copy instructions.

   -----------------------
   -- Local Subprograms --
   -----------------------

   procedure Translate_Expression_Function_Body
     (File   : in out Why_File;
      E      : Entity_Id);
   --  Generate a Why axiom that, given a function F with expression E, states
   --  that: "for all <args> => F(<args>) = E". The axiom is only generated if
   --  the body of the expression function only contains aggregates that are
   --  fully initialized.

   function Compute_Args
     (E       : Entity_Id;
      Binders : Binder_Array) return W_Expr_Array;
   --  Given a function entity, and an array of logical binders,
   --  compute a call of the logical Why function corresponding to E.
   --  In general, the binder array has *more* arguments than the Ada entity,
   --  because of effects. Note that these effect variables are not bound here,
   --  they refer to the global variables

   function Compute_Binders (E : Entity_Id) return Binder_Array;
   --  Return Why binders for the parameters of subprogram E. The array is
   --  a singleton of unit type if E has no parameters.

   function Compute_Context
     (Params : Translation_Params;
      E            : Entity_Id;
      Initial_Body : W_Prog_Id;
      Post_Check   : W_Prog_Id) return W_Prog_Id;
   --  Deal with object declarations at the beginning of the function.
   --  For local variables that originate from the source, simply assign
   --  the new value to the variable; Such variables have been declared
   --  globally.
   --  For local variables that are introduced by the compiler, add a "let"
   --  binding to Why body for each local variable of the procedure.

   function Compute_Contract_Case
     (Params : Translation_Params;
      E      : Entity_Id) return W_Prog_Id;
   --  Generate checks that:
   --  * the Requires clauses do not raise exceptions when the precondition is
   --    True;
   --  * the Ensures clauses do not raise exceptions when reaching the end of
   --    the subprogram;
   --  * the contracts are satisfied when reaching the end of the subprogram.

   function Compute_Effects (File : in out Why_File;
                             E    : Entity_Id) return W_Effects_Id;
   --  Compute the effects of the generated Why function.

   function Compute_Logic_Binders (E : Entity_Id) return Binder_Array;
   --  Return Why binders for the parameters and read effects of function E.
   --  The array is a singleton of unit type if E has no parameters and no
   --  effects.

   function Compute_Raw_Binders (E : Entity_Id) return Binder_Array;
   --  Return Why binders for the parameters of subprogram E. The array is
   --  empty if E has no parameters.

   function Compute_Spec
     (Params : Translation_Params;
      E      : Entity_Id;
      Kind   : Name_Id;
      Domain : EW_Domain) return W_Expr_Id;
   --  Compute the precondition or postcondition of the generated Why function.
   --  Kind is Name_Precondition or Name_Postcondition to specify which one is
   --  computed.

   function Get_Location_For_Postcondition (E : Entity_Id) return Node_Id;
   --  Return a node with a proper location for the postcondition of E, if any

   ------------------
   -- Compute_Args --
   ------------------

   function Compute_Args
     (E       : Entity_Id;
      Binders : Binder_Array) return W_Expr_Array
   is
      Cnt    : Integer := 1;
      Result : W_Expr_Array (1 .. Binders'Last);
      Ada_Binders : constant List_Id :=
                      Parameter_Specifications (Get_Subprogram_Spec (E));
      Arg_Length  : constant Nat := List_Length (Ada_Binders);

   begin
      if Arg_Length = 0
        and then not Has_Global_Reads (E)
      then
         return W_Expr_Array'(1 => New_Void);
      end if;

      while Cnt <= Integer (Arg_Length) loop
         Result (Cnt) := +Binders (Cnt).B_Name;
         Cnt := Cnt + 1;
      end loop;

      while Cnt <= Binders'Last loop
         Result (Cnt) :=
           New_Deref
             (Right =>
                  To_Why_Id (Get_Name_String
                     (Get_Symbol (Binders (Cnt).B_Name))));
         Cnt := Cnt + 1;
      end loop;

      return Result;
   end Compute_Args;

   ---------------------
   -- Compute_Binders --
   ---------------------

   function Compute_Binders (E : Entity_Id) return Binder_Array is
      Binders : constant Binder_Array := Compute_Raw_Binders (E);
   begin
      --  If E has no parameters, return a singleton of unit type

      if Binders'Length = 0 then
         return (1 => Unit_Param);
      else
         return Binders;
      end if;
   end Compute_Binders;

   ---------------------
   -- Compute_Context --
   ---------------------

   function Compute_Context
     (Params : Translation_Params;
      E            : Entity_Id;
      Initial_Body : W_Prog_Id;
      Post_Check   : W_Prog_Id) return W_Prog_Id
   is
      R        : W_Prog_Id := Initial_Body;
      Node : constant Node_Id := Decls.Get_Subprogram_Body (E);
   begin
      R := Transform_Declarations_Block (Declarations (Node), R);

      --  Enclose the subprogram body in a try-block, so that return
      --  statements can be translated as raising exceptions.

      declare
         Raise_Stmt : constant W_Prog_Id :=
                        New_Raise
                          (Ada_Node => Node,
                           Name     => To_Ident (WNE_Result_Exc));
         Result_Var : constant W_Prog_Id :=
                        (if Ekind (E) = E_Function then
                         New_Deref
                           (Ada_Node => Node,
                            Right    => Result_Name)
                         else New_Void);
      begin
         R :=
           New_Try_Block
             (Prog    => Sequence (R, Raise_Stmt),
              Handler =>
                (1 =>
                   New_Handler
                     (Name => To_Ident (WNE_Result_Exc),
                      Def  => Sequence (Post_Check, Result_Var))));
      end;

      declare
         use Old_Nodes;
         C : Cursor := Old_List.First;
      begin
         while Has_Element (C) loop
            declare
               N : constant Old_Node := Element (C);
            begin
               R :=
                 New_Binding
                   (Name    =>
                        New_Identifier (Symbol => N.Why_Name,
                                        Domain => EW_Prog),
                    Def     => +Transform_Expr (N.Ada_Node, EW_Prog, Params),
                    Context => +R);
               Next (C);
            end;
         end loop;
      end;
      return R;
   end Compute_Context;

   ---------------------
   -- Compute_Effects --
   ---------------------

   function Compute_Effects (File : in out Why_File;
                             E    : Entity_Id) return W_Effects_Id is
      Read_Names      : Name_Set.Set;
      Write_Names     : Name_Set.Set;
      Eff             : constant W_Effects_Id := New_Effects;

      Ada_Binders : constant List_Id :=
                      Parameter_Specifications (Get_Subprogram_Spec (E));

   begin
      --  Collect global variables potentially read and written

      Read_Names  := Get_Reads (E);
      Write_Names := Get_Writes (E);

      for Name of Write_Names loop
         Effects_Append_To_Writes
           (Eff,
            To_Why_Id (Obj => Name.all));
      end loop;

      --  Add all OUT and IN OUT parameters as potential writes

      declare
         Arg : Node_Id;
         Id  : Entity_Id;
      begin
         if Is_Non_Empty_List (Ada_Binders) then
            Arg := First (Ada_Binders);
            while Present (Arg) loop
               Id := Defining_Identifier (Arg);

               if Ekind_In (Id, E_Out_Parameter, E_In_Out_Parameter) then
                  Effects_Append_To_Writes
                    (Eff,
                     New_Identifier (Name => Full_Name (Id)));
               end if;

               Next (Arg);
            end loop;
         end if;
      end;

      for Name of Read_Names loop
         Effects_Append_To_Reads (Eff, To_Why_Id (Obj => Name.all));
      end loop;

      Add_Effect_Imports (File, Read_Names);
      Add_Effect_Imports (File, Write_Names);

      return +Eff;
   end Compute_Effects;

   ---------------------------
   -- Compute_Logic_Binders --
   ---------------------------

   function Compute_Logic_Binders (E : Entity_Id) return Binder_Array is
      Binders     : constant Binder_Array := Compute_Raw_Binders (E);
      Read_Names  : Name_Set.Set;
      Num_Binders : Integer;
      Count       : Integer;

   begin
      --  Collect global variables potentially read

      Read_Names := Get_Reads (E);

      --  If E has no parameters and no read effects, return a singleton of
      --  unit type.

      Num_Binders := Binders'Length + Integer (Read_Names.Length);

      if Num_Binders = 0 then
         return (1 => Unit_Param);

      else
         declare
            Result : Binder_Array (1 .. Num_Binders);

         begin
            --  First, copy all binders for parameters of E

            Result (1 .. Binders'Length) := Binders;

            --  Next, add binders for read effects of E

            Count := Binders'Length + 1;
            for R of Read_Names loop
               Result (Count) :=
                 (Ada_Node => Empty,
                  B_Name   => New_Identifier (Name => R.all),
                  B_Type   =>
                    New_Abstract_Type (Name => To_Why_Type (R.all)),
                  Modifier => None);
               Count := Count + 1;
            end loop;

            return Result;
         end;
      end if;
   end Compute_Logic_Binders;

   -------------------------
   -- Compute_Raw_Binders --
   -------------------------

   function Compute_Raw_Binders (E : Entity_Id) return Binder_Array is
      Params : constant List_Id :=
                 Parameter_Specifications (Get_Subprogram_Spec (E));
      Result : Binder_Array (1 .. Integer (List_Length (Params)));
      Param  : Node_Id;
      Count  : Integer;

   begin
      Param := First (Params);
      Count := 1;
      while Present (Param) loop

         --  We do not want to add a dependency to the Id entity here, so we
         --  set the ada node to empty. However, we still need the entity for
         --  the Name_Map of the translation, so we store it in the binder.

         declare
            Id   : constant Node_Id := Defining_Identifier (Param);
            Name : constant W_Identifier_Id :=
              New_Identifier (Ada_Node => Empty, Name => Full_Name (Id));
         begin
            Result (Count) :=
              (Ada_Node => Id,
               B_Name   => Name,
               Modifier => (if Is_Mutable (Id) then Ref_Modifier else None),
               B_Type   => +Why_Prog_Type_Of_Ada_Obj (Id, True));
            Next (Param);
            Count := Count + 1;
         end;
      end loop;

      return Result;
   end Compute_Raw_Binders;

   ---------------------------
   -- Compute_Contract_Case --
   ---------------------------

   function Compute_Contract_Case
     (Params : Translation_Params;
      E      : Entity_Id) return W_Prog_Id
   is
      CTC : Node_Id;
      Cur : W_Prog_Id := New_Void;

      function One_Contract_Case
        (CTC    : Node_Id;
         Domain : EW_Domain) return W_Prog_Id;
      --  Generate checks for the contract case CTC

      function One_Contract_Case
        (CTC    : Node_Id;
         Domain : EW_Domain) return W_Prog_Id
      is
         Req : constant Node_Id :=
                 Expression (Get_Requires_From_CTC_Pragma (CTC));
         Ens : constant Node_Id :=
                 Expression (Get_Ensures_From_CTC_Pragma (CTC));
         W   : constant W_Expr_Id :=
                 New_Conditional
                   (Ada_Node  => CTC,
                    Domain    => Domain,
                    Condition =>
                      Transform_Attribute_Old (Req, Domain, Params),
                    Then_Part =>
                      Transform_Expr (Ens, Domain, Params),
                    Else_Part =>
                      New_Literal
                        (Domain => Domain, Value => EW_True));
      begin
         if Domain = EW_Prog then
            return New_Ignore (Prog => +W);
         else
            return New_Assert
              (Pred => +New_Located_Expr (CTC, W, VC_Postcondition, EW_Pred));
         end if;
      end One_Contract_Case;

   begin
      CTC := Spec_CTC_List (Contract (E));
      while Present (CTC) loop
         if Pragma_Name (CTC) = Name_Contract_Case then
            declare
               W_RE   : constant W_Prog_Id := One_Contract_Case (CTC, EW_Prog);
               W_Post : constant W_Prog_Id := One_Contract_Case (CTC, EW_Pred);
            begin
               Cur := Sequence (Cur, Sequence (W_RE, W_Post));
            end;
         end if;

         CTC := Next_Pragma (CTC);
      end loop;

      return Cur;
   end Compute_Contract_Case;

   ------------------
   -- Compute_Spec --
   ------------------

   function Compute_Spec
     (Params : Translation_Params;
      E      : Entity_Id;
      Kind   : Name_Id;
      Domain : EW_Domain) return W_Expr_Id
   is
      Cur_Spec : W_Expr_Id := Why_Empty;
      PPC      : Node_Id;
   begin
      PPC := Spec_PPC_List (Contract (E));
      while Present (PPC) loop
         if Pragma_Name (PPC) = Kind then
            declare
               Expr : constant Node_Id :=
                 Expression (First (Pragma_Argument_Associations (PPC)));
               Why_Expr : constant W_Expr_Id :=
                 Transform_Expr (Expr, Domain, Params);
            begin
               if Cur_Spec /= Why_Empty then
                  Cur_Spec :=
                    New_And_Then_Expr
                      (Left   => Why_Expr,
                       Right  => Cur_Spec,
                       Domain => Domain);
               else
                  Cur_Spec := Why_Expr;
               end if;
            end;
         end if;

         PPC := Next_Pragma (PPC);
      end loop;

      if Cur_Spec /= Why_Empty then
         return Cur_Spec;
      else
         return New_Label (Domain => Domain,
                           Name   => To_Ident (WNE_AutoGen),
                           Def    =>
                             New_Literal (Value  => EW_True,
                                          Domain => Domain));
      end if;
   end Compute_Spec;

   --------------------------------------
   -- Generate_VCs_For_Subprogram_Body --
   --------------------------------------

   procedure Generate_VCs_For_Subprogram_Body
     (File   : in out Why_File;
      E      : Entity_Id)
   is
      Name       : constant String := Full_Name (E);
      Body_N     : constant Node_Id := Decls.Get_Subprogram_Body (E);
      Post_N     : constant Node_Id := Get_Location_For_Postcondition (E);
      Pre        : W_Pred_Id;
      Post       : W_Pred_Id;
      Post_Check : W_Prog_Id;
      Params     : Translation_Params;

   begin
      --  We open a new theory, so that the context is fresh for that
      --  subprogram

      Open_Theory (File, Name & "__def");
      Current_Subp := E;

      --  First, clear the list of translations for X'Old expressions, and
      --  create a new identifier for F'Result.

      Old_List.Clear;
      Result_Name := New_Result_Temp_Identifier.Id (Name);

      --  Generate code to detect possible run-time errors in the postcondition

      Params := (File        => File.File,
                 Theory      => File.Cur_Theory,
                 Phase       => Generate_VCs_For_Post,
                 Ref_Allowed => True,
                 Name_Map    => Ada_Ent_To_Why.Empty_Map);
      Post_Check :=
        Sequence
          (New_Ignore (Prog =>
                       +Compute_Spec (Params, E, Name_Postcondition, EW_Prog)),
           Compute_Contract_Case (Params, E));

      --  Set the phase to Generate_Contract_For_Body from now on, so that
      --  occurrences of F'Result are properly translated as Result_Name.

      Params.Phase := Generate_Contract_For_Body;

      --  Translate contract of E

      Pre  := +Compute_Spec (Params, E, Name_Precondition, EW_Pred);
      Post := +Compute_Spec (Params, E, Name_Postcondition, EW_Pred);

      --  Set the phase to Generate_VCs_For_Body from now on, so that
      --  occurrences of X'Old are properly translated as reference to the
      --  corresponding binder.

      Params.Phase := Generate_VCs_For_Body;

      --  Declare a global variable to hold the result of a function

      if Ekind (E) = E_Function then
         Emit
           (File.Cur_Theory,
            New_Global_Ref_Declaration
              (Name     => Result_Name,
               Ref_Type => Why_Logic_Type_Of_Ada_Type (Etype (E))));
      end if;

      --  Generate code to detect possible run-time errors in body

      Emit (File.Cur_Theory,
        New_Function_Def
          (Domain  => EW_Prog,
           Name    => To_Ident (WNE_Def),
           Binders => (1 => Unit_Param),
           Pre     => Pre,
           Post    =>
             +New_Located_Expr (Post_N, +Post, VC_Postcondition, EW_Pred),
           Def     =>
             +Compute_Context
               (Params,
                E,
                Transform_Statements
                  (Statements
                     (Handled_Statement_Sequence (Body_N))),
              Post_Check)));

      --  We should *not* filter our own entity, it is needed for recursive
      --  calls

      Close_Theory (File, Filter_Entity => Empty);
   end Generate_VCs_For_Subprogram_Body;

   --------------------------------------
   -- Generate_VCs_For_Subprogram_Spec --
   --------------------------------------

   procedure Generate_VCs_For_Subprogram_Spec
     (File : in out Why_File;
      E    : Entity_Id)
   is
      Name    : constant String := Full_Name (E);
      Binders : constant Binder_Array := Compute_Binders (E);
      Params  : Translation_Params;
   begin
      Open_Theory (File, Name & "__pre");
      Current_Subp := E;
      Params :=
        (File        => File.File,
         Theory      => File.Cur_Theory,
         Phase       => Generate_VCs_For_Pre,
         Ref_Allowed => True,
         Name_Map    => Ada_Ent_To_Why.Empty_Map);

      Emit
        (File.Cur_Theory,
         New_Function_Def
           (Domain  => EW_Prog,
            Name    => To_Ident (WNE_Pre_Check),
            Binders => Binders,
            Def     => Compute_Spec (Params, E, Name_Precondition, EW_Prog)));
      Close_Theory (File, Filter_Entity => E);
   end Generate_VCs_For_Subprogram_Spec;

   ------------------------------------
   -- Get_Location_For_Postcondition --
   ------------------------------------

   function Get_Location_For_Postcondition (E : Entity_Id) return Node_Id is
      PPC : Node_Id;

   begin
      PPC := Spec_PPC_List (Contract (E));
      while Present (PPC) loop
         if Pragma_Name (PPC) = Name_Postcondition then
            return Expression (First (Pragma_Argument_Associations (PPC)));
         end if;

         PPC := Next_Pragma (PPC);
      end loop;

      return Empty;
   end Get_Location_For_Postcondition;

   ------------------
   -- Name_For_Old --
   ------------------

   function Name_For_Old (N : Node_Id) return W_Identifier_Id is
      Cnt : constant Natural := Natural (Old_List.Length);
      Rec : constant Old_Node :=
              (Ada_Node => N,
               Why_Name => NID ("__gnatprove_old___" & Int_Image (Cnt)));
   begin
      Old_List.Append (Rec);
      return New_Identifier (Symbol => Rec.Why_Name, Domain => EW_Term);
   end Name_For_Old;

   ---------------------
   -- Name_For_Result --
   ---------------------

   function Name_For_Result return W_Identifier_Id is
   begin
      pragma Assert (Result_Name /= Why_Empty);
      return Result_Name;
   end Name_For_Result;

   ----------------------------------------
   -- Translate_Expression_Function_Body --
   ----------------------------------------

   procedure Translate_Expression_Function_Body
     (File   : in out Why_File;
      E      : Entity_Id)
   is
      Expr_Fun_N : constant Node_Id := Get_Expression_Function (E);
      pragma Assert (Present (Expr_Fun_N));
      Logic_Func_Binders : constant Binder_Array :=
        Compute_Logic_Binders (E);
      Logic_Id           : constant W_Identifier_Id :=
        To_Why_Id (E, Domain => EW_Term, Local => True);

      Params : Translation_Params;

   begin
      --  If the body of the expression function contains aggregates that are
      --  not fully initialized, skip the definition of an axiom for this
      --  expression function.

      if not
        All_Aggregates_Are_Fully_Initialized (Expression (Expr_Fun_N))
      then
         return;
      end if;

      Params :=
        (File        => File.File,
         Theory      => File.Cur_Theory,
         Phase       => Translation,
         Ref_Allowed => False,
         Name_Map    => Ada_Ent_To_Why.Empty_Map);

      for Binder of Logic_Func_Binders loop
         declare
            A : constant Node_Id := Binder.Ada_Node;
         begin
            if Present (A) then
               Ada_Ent_To_Why.Insert (Params.Name_Map,
                                      Unique_Entity (A),
                                      +Binder.B_Name);
            else

               --  if there is no Ada_Node, this in a binder generated from
               --  an effect; we add the parameter in the name map using its
               --  unique name

               Ada_Ent_To_Why.Insert
                 (Params.Name_Map,
                  Get_Name_String (Get_Symbol (Binder.B_Name)),
                  +Binder.B_Name);

            end if;
         end;
      end loop;

      --  Given an expression function F with expression E, define an axiom
      --  that states that: "for all <args> => F(<args>) = E".
      --  There is no need to use the precondition here, as the above axiom
      --  is always sound.

      if Etype (E) = Standard_Boolean then
         Emit
           (File.Cur_Theory,
            New_Defining_Bool_Axiom
              (Name    => Logic_Id,
               Binders => Logic_Func_Binders,
               Def     => +Transform_Expr (Expression (Expr_Fun_N),
                                           EW_Pred,
                                           Params)));

      else
         Emit
           (File.Cur_Theory,
            New_Defining_Axiom
              (Name        => Logic_Id,
               Return_Type => Get_EW_Type (Expression (Expr_Fun_N)),
               Binders     => Logic_Func_Binders,
               Def         =>
               +Transform_Expr
                 (Expression (Expr_Fun_N),
                  Expected_Type => EW_Abstract (Etype (E)),
                  Domain        => EW_Term,
                  Params        => Params)));
      end if;
   end Translate_Expression_Function_Body;

   -------------------------------
   -- Translate_Subprogram_Spec --
   -------------------------------

   procedure Translate_Subprogram_Spec
     (File        : in out Why_File;
      E           : Entity_Id;
      Is_Expr_Fun : Boolean)
   is
      Name         : constant String := Full_Name (E);
      Effects      : W_Effects_Id;
      Logic_Func_Binders : constant Binder_Array :=
                             Compute_Logic_Binders (E);

      Func_Binders : constant Binder_Array := Compute_Binders (E);
      Params       : Translation_Params;
      Pre          : W_Pred_Id;
      Post         : W_Pred_Id;
      Prog_Id      : constant W_Identifier_Id :=
        To_Why_Id (E, Domain => EW_Prog, Local => True);
   begin
      Open_Theory (File, Name);

      Params :=
        (File        => File.File,
         Theory      => File.Cur_Theory,
         Phase       => Translation,
         Ref_Allowed => True,
         Name_Map    => Ada_Ent_To_Why.Empty_Map);

      --  We fill the map of parameters, so that in the pre and post, we use
      --  local names of the parameters, instead of the global names

      for Binder of Func_Binders loop
         declare
            A : constant Node_Id := Binder.Ada_Node;
         begin

            --  If the Ada_Node is empty, it's not an interesting binder (e.g.
            --  void_param)

            if Present (A) then
               Ada_Ent_To_Why.Insert (Params.Name_Map,
                                      Unique_Entity (A),
                                      +Binder.B_Name);
            end if;
         end;
      end loop;

      Effects := Compute_Effects (File, E);

      Pre := +Compute_Spec (Params, E, Name_Precondition, EW_Pred);
      Post := +Compute_Spec (Params, E, Name_Postcondition, EW_Pred);

      if Ekind (E) = E_Function then
         declare
            Logic_Func_Args : constant W_Expr_Array :=
              Compute_Args (E, Logic_Func_Binders);
            Logic_Id        : constant W_Identifier_Id :=
              To_Why_Id (E, Domain => EW_Term, Local => True);

            --  Each function has in its postcondition that its result is equal
            --  to the application of the corresponding logic function to the
            --  same arguments.

            Param_Post : constant W_Pred_Id :=
                            +New_And_Expr
                              (Left   => New_Relation
                                   (Op      => EW_Eq,
                                    Op_Type =>
                                      Get_EW_Type (+Why_Logic_Type_Of_Ada_Type
                                      (Etype (E))),
                                    Left    => +To_Ident (WNE_Result),
                                    Right   =>
                                    New_Call
                                      (Domain  => EW_Term,
                                       Name    => Logic_Id,
                                       Args    => Logic_Func_Args),
                                    Domain => EW_Pred),
                               Right  => +Post,
                               Domain => EW_Pred);

         begin
            --  Generate a logic function

            Emit
              (File.Cur_Theory,
               New_Function_Decl
                 (Domain      => EW_Term,
                  Name        => Logic_Id,
                  Binders     => Logic_Func_Binders,
                  Return_Type =>
                     +Why_Logic_Type_Of_Ada_Type
                       (Etype (E))));

            Emit
              (File.Cur_Theory,
               New_Function_Decl
                 (Domain      => EW_Prog,
                  Name        => Prog_Id,
                  Binders     => Func_Binders,
                  Return_Type => +Why_Logic_Type_Of_Ada_Type (Etype (E)),
                  Effects     => Effects,
                  Pre         => Pre,
                  Post        => Param_Post));
         end;
      else
         Emit
           (File.Cur_Theory,
            New_Function_Decl
              (Domain      => EW_Prog,
               Name        => Prog_Id,
               Binders     => Func_Binders,
               Return_Type => New_Base_Type (Base_Type => EW_Unit),
               Effects     => Effects,
               Pre         => Pre,
               Post        => Post));
      end if;
      if Is_Expr_Fun then
         Translate_Expression_Function_Body (File, E);
      end if;
      Close_Theory (File, Filter_Entity => E);
   end Translate_Subprogram_Spec;

end Gnat2Why.Subprograms;
