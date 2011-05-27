------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                      G N A T 2 W H Y - T Y P E S                         --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                       Copyright (C) 2010-2011, AdaCore                   --
--                                                                          --
-- gnat2why is  free  software;  you can redistribute it and/or modify it   --
-- under terms of the  GNU General Public License as published  by the Free --
-- Software Foundation;  either version  2,  or  (at your option) any later --
-- version. gnat2why is distributed in the hope that it will  be  useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHAN-  --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details. You  should  have  received a copy of the GNU --
-- General Public License  distributed with GNAT; see file COPYING. If not, --
-- write to the Free Software Foundation,  51 Franklin Street, Fifth Floor, --
-- Boston,                                                                  --
--                                                                          --
-- gnat2why is maintained by AdaCore (http://www.adacore.com)               --
--                                                                          --
------------------------------------------------------------------------------

with Atree;              use Atree;
with Einfo;              use Einfo;
with Gnat2Why.Decls;     use Gnat2Why.Decls;
with Namet;              use Namet;
with Nlists;             use Nlists;
with Sem_Eval;           use Sem_Eval;
with Sinfo;              use Sinfo;
with Stand;              use Stand;
with String_Utils;       use String_Utils;
with Why;                use Why;
with Why.Conversions;    use Why.Conversions;
with Why.Atree.Builders; use Why.Atree.Builders;
with Why.Gen.Arrays;     use Why.Gen.Arrays;
with Why.Gen.Enums;      use Why.Gen.Enums;
with Why.Gen.Ints;       use Why.Gen.Ints;
with Why.Gen.Names;      use Why.Gen.Names;
with Why.Gen.Records;    use Why.Gen.Records;

with Gnat2Why.Subprograms; use Gnat2Why.Subprograms;

package body Gnat2Why.Types is

   procedure Declare_Ada_Abstract_Signed_Int_From_Range
      (File : W_File_Id;
       Name : String;
       Rng  : Node_Id);
   --  Same as Declare_Ada_Abstract_Signed_Int but extract range information
   --  from node.

   ------------------------------------------------
   -- Declare_Ada_Abstract_Signed_Int_From_Range --
   ------------------------------------------------

   procedure Declare_Ada_Abstract_Signed_Int_From_Range
      (File : W_File_Id;
       Name : String;
       Rng  : Node_Id)
   is
      Range_Node : constant Node_Id := Get_Range (Rng);
   begin
      Declare_Ada_Abstract_Signed_Int
        (File,
         Name,
         Expr_Value (Low_Bound (Range_Node)),
         Expr_Value (High_Bound (Range_Node)));
   end Declare_Ada_Abstract_Signed_Int_From_Range;

   -------------------------------
   -- Why_Logic_Type_Of_Ada_Obj --
   -------------------------------

   function Why_Logic_Type_Of_Ada_Obj (N : Node_Id)
      return W_Primitive_Type_Id is
      Ty : constant Node_Id := Etype (N);
   begin
      return New_Abstract_Type (Ty, New_Identifier (Full_Name (Ty)));
   end  Why_Logic_Type_Of_Ada_Obj;

   --------------------------------
   -- Why_Logic_Type_Of_Ada_Type --
   --------------------------------

   function Why_Logic_Type_Of_Ada_Type (Ty : Node_Id)
      return W_Primitive_Type_Id is
   begin
      return New_Abstract_Type (Ty, New_Identifier (Full_Name (Ty)));
   end  Why_Logic_Type_Of_Ada_Type;

   -------------------------------------
   -- Why_Type_Decl_of_Full_Type_Decl --
   -------------------------------------

   procedure Why_Type_Decl_of_Full_Type_Decl
      (File       : W_File_Id;
       Ident_Node : Node_Id;
       Def_Node   : Node_Id)
   is
      Name_Str : constant String := Full_Name (Ident_Node);
   begin
      case Nkind (Def_Node) is
         when N_Enumeration_Type_Definition =>
            if Ident_Node = Standard_Boolean then
               null;
            elsif Ident_Node = Standard_Character or else
                    Ident_Node = Standard_Wide_Character or else
                    Ident_Node = Standard_Wide_Wide_Character then
               Declare_Ada_Abstract_Signed_Int_From_Range
                 (File,
                  Name_Str,
                  Ident_Node);
            else
               --  A normal enumeration type
               declare
                  Cursor       : Node_Or_Entity_Id :=
                                   Nlists.First (Literals (Def_Node));
                  Constructors : String_Lists.List :=
                                   String_Lists.Empty_List;
               begin
                  while Nkind (Cursor) /= N_Empty loop
                     Constructors.Append (
                       Get_Name_String (Chars (Cursor)));
                     Cursor := Next (Cursor);
                  end loop;
                  Declare_Ada_Enum_Type (File, Name_Str, Constructors);
               end;
            end if;

         when N_Signed_Integer_Type_Definition =>
            Declare_Ada_Abstract_Signed_Int_From_Range
              (File,
               Name_Str,
               Def_Node);

         when N_Unconstrained_Array_Definition =>
            declare
               Component_Type : constant String :=
                  Full_Name
                     (Entity
                        (Subtype_Indication
                           (Component_Definition (Def_Node))));
            begin
               Declare_Ada_Unconstrained_Array
                 (File,
                  Name_Str,
                  Component_Type);
            end;

         when N_Record_Definition =>
            if not Null_Present (Def_Node) then
               declare
                  Builder : W_Logic_Type_Id;
               begin
                  Start_Ada_Record_Declaration (File,
                                                Name_Str,
                                                Builder);
                  declare
                     use String_Lists;

                     Comps   : constant List_Id :=
                                 Component_Items (Component_List (Def_Node));
                     Item    : Node_Id := First (Comps);
                     C_Names : List;
                  begin
                     while Present (Item) loop
                        declare
                           C_Ident : constant Node_Id :=
                                       Defining_Identifier (Item);
                           C_Name  : constant String :=
                                       Full_Name (C_Ident);
                           C_Type  : constant Node_Id :=
                                       Etype
                                         (Subtype_Indication
                                          (Component_Definition (Item)));
                        begin
                           Add_Component
                             (File,
                              C_Name,
                              Why_Logic_Type_Of_Ada_Type (C_Type),
                              Builder);
                           C_Names.Append (C_Name);
                           Next (Item);
                        end;
                     end loop;

                     Freeze_Ada_Record (File, Name_Str, C_Names, Builder);
                  end;
               end;
            end if;

         when N_Floating_Point_Definition
            | N_Ordinary_Fixed_Point_Definition
            =>
            --  ??? We do nothing here for now
            null;
         when N_Constrained_Array_Definition =>
            declare
               Component_Type : constant String :=
                  Full_Name
                     (Etype
                        (Subtype_Indication (Component_Definition
                           (Def_Node))));
               Rng            : constant Node_Id :=
                  Get_Range (First_Index (Ident_Node));
            begin
               Declare_Ada_Constrained_Array
                  (File,
                   Name_Str,
                   Component_Type,
                   Expr_Value (Low_Bound (Rng)),
                   Expr_Value (High_Bound (Rng)));
            end;

         when N_Derived_Type_Definition =>
            --  ??? Is this correct?
            Why_Type_Decl_of_Subtype_Decl
               (File,
                Ident_Node,
                Subtype_Indication (Def_Node));

         when others =>
            raise Not_Implemented;
      end case;
   end Why_Type_Decl_of_Full_Type_Decl;

   -----------------------------------
   -- Why_Type_Decl_of_Subtype_Decl --
   -----------------------------------

   procedure Why_Type_Decl_of_Subtype_Decl
      (File       : W_File_Id;
       Ident_Node : Node_Id;
       Sub_Ind    : Node_Id)
   is
      Name_Str : constant String := Full_Name (Ident_Node);
   begin
      pragma Unreferenced (Sub_Ind);
      case Ekind (Ident_Node) is
         when Discrete_Kind =>
            --  For any subtype of a discrete type, we generate an "integer"
            --  type in Why. This is also true for enumeration types; we
            --  actually do not express that the subtype is an enumeration
            --  type, we simply state that it is in a given range.
            Declare_Ada_Abstract_Signed_Int_From_Range
              (File,
               Name_Str,
               Ident_Node);

         when Array_Kind =>
            declare
               Base : Node_Id := Ident_Node;
               Rng  : constant Node_Id :=
                  Get_Range (First_Index (Ident_Node));
            begin
               while Etype (Base) /= Base loop
                  Base := Etype (Base);
               end loop;
               --  We need to
               --    * find the Index type
               --    * find the component type
               Declare_Ada_Constrained_Array
                  (File,
                   Name_Str,
                   Full_Name (Component_Type (Base)),
                   Expr_Value (Low_Bound (Rng)),
                   Expr_Value (High_Bound (Rng)));
            end;

         when others =>
            raise Program_Error;
      end case;
   end Why_Type_Decl_of_Subtype_Decl;

   -------------------------------
   -- Why_Prog_Type_Of_Ada_Type --
   -------------------------------

   function Why_Prog_Type_Of_Ada_Type (Ty : Node_Id; Is_Mutable : Boolean)
      return W_Simple_Value_Type_Id
   is
      Name : constant String := Full_Name (Ty);
      Base : constant W_Primitive_Type_Id :=
            New_Abstract_Type (Ty, New_Identifier (Name));
   begin
      if Is_Mutable then
         return New_Ref_Type (Ada_Node => Ty, Aliased_Type => Base);
      else
         return +Base;
      end if;
   end  Why_Prog_Type_Of_Ada_Type;

   function Why_Prog_Type_Of_Ada_Type (N : Node_Id)
      return W_Simple_Value_Type_Id
   is
   begin
      return Why_Prog_Type_Of_Ada_Type (Etype (N), Is_Mutable (N));
   end  Why_Prog_Type_Of_Ada_Type;
end Gnat2Why.Types;
