------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                         G N A T 2 W H Y - D E C L S                      --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                       Copyright (C) 2010-2016, AdaCore                   --
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

with Atree;                  use Atree;
with Einfo;                  use Einfo;
with GNAT.Source_Info;
with Gnat2Why.Expr;          use Gnat2Why.Expr;
with Namet;                  use Namet;
with Sinfo;                  use Sinfo;
with Sinput;                 use Sinput;
with SPARK_Definition;       use SPARK_Definition;
with SPARK_Frame_Conditions;
with SPARK_Util;             use SPARK_Util;
with Ada.Strings;            use Ada.Strings;
with Ada.Strings.Fixed;      use Ada.Strings.Fixed;
with String_Utils;           use String_Utils;
with Why.Atree.Accessors;    use Why.Atree.Accessors;
with Why.Atree.Builders;     use Why.Atree.Builders;
with Why.Atree.Modules;      use Why.Atree.Modules;
with Why.Gen.Binders;        use Why.Gen.Binders;
with Why.Gen.Decl;           use Why.Gen.Decl;
with Why.Gen.Expr;           use Why.Gen.Expr;
with Why.Gen.Names;          use Why.Gen.Names;
with Why.Ids;                use Why.Ids;
with Why.Inter;              use Why.Inter;
with Why.Sinfo;              use Why.Sinfo;
with Why.Types;              use Why.Types;

package body Gnat2Why.Decls is

   ------------------------------
   -- Translate_Abstract_State --
   ------------------------------

   procedure Translate_Abstract_State
     (File : in out Why_Section;
      E    : Entity_Id)
   is
      Var : constant Item_Type := Mk_Item_Of_Entity (E);
   begin
      Open_Theory (File, E_Module (E),
                   Comment =>
                     "Module for defining a ref holding the value "
                       & "of abstract state "
                       & """" & Get_Name_String (Chars (E)) & """"
                       & (if Sloc (E) > 0 then
                            " defined at " & Build_Location_String (Sloc (E))
                          else "")
                       & ", created in " & GNAT.Source_Info.Enclosing_Entity);

      --  We generate a global ref

      Emit
        (File.Cur_Theory,
         New_Global_Ref_Declaration
           (Name     => To_Why_Id (E, Local => True),
            Labels   => Name_Id_Sets.Empty_Set,
            Ref_Type => EW_Private_Type));

      Insert_Item (E, Var);

      Close_Theory (File,
                    Kind => Standalone_Theory);
   end Translate_Abstract_State;

   ------------------------
   -- Translate_Constant --
   ------------------------

   procedure Translate_Constant
     (File : in out Why_Section;
      E    : Entity_Id)
   is
      Typ    : constant W_Type_Id  := Type_Of_Node (Etype (E));
   begin
      --  Start with opening the theory to define, as the creation of a
      --  function for the logic term needs the current theory to insert an
      --  include declaration.

      Open_Theory (File, E_Module (E),
                   Comment =>
                     "Module for defining the constant "
                       & """" & Get_Name_String (Chars (E)) & """"
                       & (if Sloc (E) > 0 then
                            " defined at " & Build_Location_String (Sloc (E))
                          else "")
                       & ", created in " & GNAT.Source_Info.Enclosing_Entity);

      --  We generate a "logic", whose axiom will be given in a completion

      --  It can happen that components need to be translated, for example, for
      --  discriminants of task types.
      --  In this case, the variable should have its own name and not a Why3
      --  record component name.

      Insert_Entity (E, To_Why_Id (E, No_Comp => True, Typ => Typ));

      Emit (File.Cur_Theory,
            Why.Atree.Builders.New_Function_Decl
              (Domain      => EW_Term,
               Name        => To_Why_Id
                 (E, No_Comp => True, Domain => EW_Term, Local => True),
               Binders     => (1 .. 0 => <>),
               Labels      => Get_Counterexample_Labels (E),
               Return_Type => Typ));

      Close_Theory (File,
                    Kind => Definition_Theory,
                    Defined_Entity => E);
   end Translate_Constant;

   ------------------------------
   -- Translate_Constant_Value --
   ------------------------------

   procedure Translate_Constant_Value
     (File : in out Why_Section;
      E    : Entity_Id)
   is
      Typ    : constant W_Type_Id := Type_Of_Node (Etype (E));
      Decl   : constant Node_Id := Parent (E);
      Def    : W_Term_Id;

      --  Always use the Ada type for the equality between the constant result
      --  and the translation of its initialization expression. Using "int"
      --  instead is tempting to facilitate the job of automatic provers, but
      --  it is potentially incorrect. For example for:

      --    C : constant Natural := Largest_Int + 1;

      --  we should *not* generate the incorrect axiom:

      --    axiom c__def:
      --      to_int(c) = to_int(largest_int) + 1

      --  but the correct one:

      --    axiom c__def:
      --      c = of_int (to_int(largest_int) + 1)

   begin
      --  Start with opening the theory to define, as the creation of a
      --  function for the logic term needs the current theory to insert an
      --  include declaration.

      Open_Theory (File, E_Axiom_Module (E),
                   Comment =>
                     "Module for defining the value of constant "
                       & """" & Get_Name_String (Chars (E)) & """"
                       & (if Sloc (E) > 0 then
                            " defined at " & Build_Location_String (Sloc (E))
                          else "")
                       & ", created in " & GNAT.Source_Info.Enclosing_Entity);

      --  Default values of parameters are not considered as the value of the
      --  constant representing the parameter. We do not generate an axiom
      --  for constants inserted by the compiler, as their initialization
      --  expression may not be expressible as a logical term (e.g., it may
      --  include X'Loop_Entry for a constant inserted in a block of actions).

      if Ekind (E) /= E_In_Parameter
        and then Present (Expression (Decl))
        and then Comes_From_Source (E)
      then
         Def := Get_Pure_Logic_Term_If_Possible
           (File, Expression (Decl), Typ);
      else
         Def := Why_Empty;
      end if;

      if Def /= Why_Empty then

         --  The definition of constants is done in a separate theory. This
         --  theory is added as a completion of the base theory defining the
         --  constant.

         if Is_Full_View (E) then

            --  It may be the case that the full view has a more precise type
            --  than the partial view, for example when the type of the partial
            --  view is an indefinite array. In that case, convert back to the
            --  expected type for the constant.

            if Etype (Partial_View (E)) /= Etype (E) then
               Def := W_Term_Id (Insert_Simple_Conversion
                        (Domain   => EW_Term,
                         Ada_Node => Expression (Decl),
                         Expr     => W_Expr_Id (Def),
                         To       => EW_Abstract (Etype (Partial_View (E)))));
            end if;

            Emit
              (File.Cur_Theory,
               New_Defining_Axiom
                 (Ada_Node    => E,
                  Name        =>
                    To_Why_Id (E, Domain => EW_Term, Local => False),
                  Binders     => (1 .. 0 => <>),
                  Def         => Def));

         --  In the general case, we generate a defining axiom if necessary and
         --  possible.

         else
            Emit
              (File.Cur_Theory,
               New_Defining_Axiom
                 (Ada_Node    => E,
                  Name        =>
                    To_Why_Id (E, Domain => EW_Term, Local => False),
                  Binders     => (1 .. 0 => <>),
                  Def         => Def));
         end if;
      end if;

      --  No filtering is necessary here, as the theory should on the
      --  contrary use the previously defined theory for the partial
      --  view. Attach the newly created theory as a completion of the
      --  existing one.

      Close_Theory (File,
                    Kind => Axiom_Theory,
                    Defined_Entity =>
                      (if Is_Full_View (E) then Partial_View (E) else E));
   end Translate_Constant_Value;

   -------------------------------
   -- Translate_External_Object --
   -------------------------------

   procedure Translate_External_Object (E : Entity_Name) is
      File : Why_Section renames Why_Sections (WF_Variables);

   begin
      --  Objects in axiomatized units should not be treated as external
      --  objects, since the axiomatization should define them. In particular,
      --  constants in axiomatized units should be treated as constants without
      --  variable input, which do not matter for effects, and as such do not
      --  need to be translated as external objects.

      declare
         Ent : constant Entity_Id := SPARK_Frame_Conditions.Find_Entity (E);
      begin
         if Present (Ent)
           and then Entity_In_Ext_Axioms (Ent)
         then
            return;
         end if;
      end;

      Open_Theory
        (File,
         Module =>
           New_Module (Name => NID (Capitalize_First (To_String (E))),
                       File => No_Name),
         Comment =>
           "Module declaring the external object """ & To_String (E) &
           ","" created in " & GNAT.Source_Info.Enclosing_Entity);

      Add_With_Clause (File.Cur_Theory, Ref_Module, EW_Import, EW_Module);

      Emit
        (File.Cur_Theory,
         New_Global_Ref_Declaration
           (Name     => To_Why_Id (To_String (E), Local => True),
            Labels   => Name_Id_Sets.Empty_Set,
            Ref_Type => EW_Private_Type));

      Close_Theory (File,
                    Kind => Standalone_Theory);

      --  Also generate an empty axiom module

      Open_Theory
        (File,
         New_Module (Name =>
                         NID (Capitalize_First (To_String (E)) & "__axiom"),
                     File => No_Name),
         Comment =>
           "Module giving an empty axiom for the entity "
         & """" & To_String (E) & """"
         & ", created in " & GNAT.Source_Info.Enclosing_Entity);
      Close_Theory (File,
                    Kind => Standalone_Theory);
   end Translate_External_Object;

   ---------------------------
   -- Translate_Loop_Entity --
   ---------------------------

   procedure Translate_Loop_Entity
     (File : in out Why_Section;
      E    : Entity_Id)
   is
   begin
      Open_Theory (File, E_Module (E),
                   Comment =>
                     "Module for defining "
                   & "the loop exit exception for the loop "
                   & """" & Get_Name_String (Chars (E)) & """"
                   & (if Sloc (E) > 0 then
                     " defined at " & Build_Location_String (Sloc (E))
                     else "")
                   & ", created in " & GNAT.Source_Info.Enclosing_Entity);

      Emit (File.Cur_Theory,
            New_Exception_Declaration
              (Name => Loop_Exception_Name (E, Local => True),
               Arg  => Why_Empty));

      Close_Theory (File,
                    Kind => Standalone_Theory);
   end Translate_Loop_Entity;

   ------------------------
   -- Translate_Variable --
   ------------------------

   procedure Translate_Variable
     (File : in out Why_Section;
      E    : Entity_Id)
   is
      Var    : constant Item_Type := Mk_Item_Of_Entity (E);
   begin
      Open_Theory (File, E_Module (E),
                   Comment =>
                     "Module for defining a ref holding the value of variable "
                       & """" & Get_Name_String (Chars (E)) & """"
                       & (if Sloc (E) > 0 then
                            " defined at " & Build_Location_String (Sloc (E))
                          else "")
                   & ", created in " & GNAT.Source_Info.Enclosing_Entity);

      Insert_Item (E, Var);

      --  If E is not in SPARK, only declare an object of type __private for
      --  use in effects of program functions in Why3.

      if not Entity_In_SPARK (E) then
         Emit
           (File.Cur_Theory,
            New_Global_Ref_Declaration
              (Name     => To_Local (Var.Main.B_Name),
               Labels   => Name_Id_Sets.Empty_Set,
               Ref_Type => Get_Typ (Var.Main.B_Name)));

      --  If E is in SPARK, declare various objects depending on its type and
      --  on whether the decision has been made to split the object or not.

      else
         case Var.Kind is
         when DRecord =>
            if Var.Fields.Present then

               --  generate a global ref for the fields

               Emit
                 (File.Cur_Theory,
                  New_Global_Ref_Declaration
                    (Name     => To_Local (Var.Fields.Binder.B_Name),
                     Labels   => Get_Counterexample_Labels (E),
                     Ref_Type => Get_Typ (Var.Fields.Binder.B_Name)));
            end if;

            if Var.Discrs.Present then

               --  generate a global ref or constant for the fields

               if Var.Discrs.Binder.Mutable then
                  Emit
                    (File.Cur_Theory,
                     New_Global_Ref_Declaration
                       (Name     => To_Local (Var.Discrs.Binder.B_Name),
                        Labels   => Name_Id_Sets.Empty_Set,
                        Ref_Type => Get_Typ (Var.Discrs.Binder.B_Name)));
               else
                  Emit
                    (File.Cur_Theory,
                     Why.Atree.Builders.New_Function_Decl
                       (Domain      => EW_Term,
                        Name        =>
                          To_Local (Var.Discrs.Binder.B_Name),
                        Binders     => (1 .. 0 => <>),
                        Labels      => Name_Id_Sets.Empty_Set,
                        Return_Type => Get_Typ (Var.Discrs.Binder.B_Name)));
               end if;
            end if;

            if Var.Constr.Present then

               --  generate a constant for 'Constrained attribute

                  Emit
                    (File.Cur_Theory,
                     Why.Atree.Builders.New_Function_Decl
                       (Domain      => EW_Term,
                        Name        => To_Local (Var.Constr.Id),
                        Binders     => (1 .. 0 => <>),
                        Labels      => Name_Id_Sets.Empty_Set,
                        Return_Type => Get_Typ (Var.Constr.Id)));
            end if;

            if Var.Tag.Present then

               --  generate a constant for 'Tag attribute

                  Emit
                    (File.Cur_Theory,
                     Why.Atree.Builders.New_Function_Decl
                       (Domain      => EW_Term,
                        Name        => To_Local (Var.Tag.Id),
                        Binders     => (1 .. 0 => <>),
                        Labels      => Name_Id_Sets.Empty_Set,
                        Return_Type => Get_Typ (Var.Tag.Id)));
            end if;

         when UCArray =>

            --  generate a global ref for the content

            Emit
              (File.Cur_Theory,
               New_Global_Ref_Declaration
                 (Name     => To_Local (Var.Content.B_Name),
                  Labels   => Get_Counterexample_Labels (E),
                  Ref_Type => Get_Typ (Var.Content.B_Name)));

            for D in 1 .. Var.Dim loop
               declare
                  function Bound_Dimension_To_Str
                    (Total_Dim, Num_Dim : Integer;
                     Bound_Name : String) return String
                  is
                    (if Total_Dim = 1 then Bound_Name
                     else Bound_Name &
                       " (" & Trim (Integer'Image (Num_Dim), Both) &
                       ")");

                  Ty_First   : constant W_Type_Id :=
                    Get_Typ (Var.Bounds (D).First);
                  Ty_Last    : constant W_Type_Id :=
                    Get_Typ (Var.Bounds (D).Last);
               begin

                  --  generate constants for bounds

                  Emit
                    (File.Cur_Theory,
                     Why.Atree.Builders.New_Function_Decl
                       (Domain      => EW_Term,
                        Name        => To_Local (Var.Bounds (D).First),
                        Binders     => (1 .. 0 => <>),
                        Labels      => Get_Counterexample_Labels
                          (E, Bound_Dimension_To_Str (Var.Dim, D, "'First")),
                        Return_Type => Ty_First));
                  Emit
                    (File.Cur_Theory,
                     Why.Atree.Builders.New_Function_Decl
                       (Domain      => EW_Term,
                        Name        => To_Local (Var.Bounds (D).Last),
                        Binders     => (1 .. 0 => <>),
                        Labels      => Get_Counterexample_Labels
                          (E, Bound_Dimension_To_Str (Var.Dim, D, "'Last")),
                        Return_Type => Ty_Last));
               end;
            end loop;

         when Regular =>
            begin
               --  Currently only generate values for scalar variables in
               --  counterexamples, which are always of the Regular kind.

               --  generate a global ref

               Emit
                 (File.Cur_Theory,
                  New_Global_Ref_Declaration
                    (Name     => To_Local (Var.Main.B_Name),
                     Labels   => Get_Counterexample_Labels (E),
                     Ref_Type => Get_Typ (Var.Main.B_Name)));
            end;

         when Func | Prot_Self =>
            raise Program_Error;
         end case;
      end if;

      Emit (File.Cur_Theory,
            Why.Atree.Builders.New_Function_Decl
              (Domain      => EW_Term,
               Name        => To_Local (E_Symb (E, WNE_Attr_Address)),
               Binders     => (1 .. 0 => <>),
               Labels      => Name_Id_Sets.Empty_Set,
               Return_Type => EW_Int_Type));

      Close_Theory (File,
                    Kind           => Definition_Theory,
                    Defined_Entity => E);
   end Translate_Variable;

end Gnat2Why.Decls;
