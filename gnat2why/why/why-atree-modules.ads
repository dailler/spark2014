------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                      W H Y - A T R E E - M O D U L E S                   --
--                                                                          --
--                                 S p e c                                  --
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

with Ada;                        use Ada;
with Ada.Containers.Hashed_Maps;
with Common_Containers;
with SPARK_Definition;           use SPARK_Definition;
with Why.Ids;                    use Why.Ids;
with Why.Gen.Names;              use Why.Gen.Names;

package Why.Atree.Modules is
   --  This package helps with Why modules. Today, it is only a list of
   --  predefined modules and Why files.

   ---------------------------
   --  Predefined Why Files --
   ---------------------------

   Int_File                : Name_Id;
   Real_File               : Name_Id;
   Ref_File                : Name_Id;
   Gnatprove_Standard_File : Name_Id;
   Ada_Model_File          : Name_Id;

   -----------------------------
   --  Predefined Why modules --
   -----------------------------

   --  the Why standard library

   Int_Module : W_Module_Id;
   RealInfix  : W_Module_Id;
   Ref_Module : W_Module_Id;

   --  basic Why types

   EW_Bool_Type         : W_Type_Id;
   EW_Int_Type          : W_Type_Id;
   EW_Private_Type      : W_Type_Id;         --  alias of Main.Private_Type
   EW_Prop_Type         : W_Type_Id;
   EW_Fixed_Type        : W_Type_Id;         --  alias of Main.Fixed_Type
   EW_Real_Type         : W_Type_Id;
   EW_BitVector_8_Type  : W_Type_Id;
   EW_BitVector_16_Type : W_Type_Id;
   EW_BitVector_32_Type : W_Type_Id;
   EW_BitVector_64_Type : W_Type_Id;
   EW_Unit_Type         : W_Type_Id;

   --  Modules of file "ada__model.mlw"

   Static_Discrete        : W_Module_Id;
   Static_Modular_8       : W_Module_Id;
   Static_Modular_16      : W_Module_Id;
   Static_Modular_32      : W_Module_Id;
   Static_Modular_64      : W_Module_Id;
   Static_Modular_lt8     : W_Module_Id;
   Static_Modular_lt16    : W_Module_Id;
   Static_Modular_lt32    : W_Module_Id;
   Static_Modular_lt64    : W_Module_Id;
   Dynamic_Modular        : W_Module_Id;
   Dynamic_Discrete       : W_Module_Id;
   Static_Fixed_Point     : W_Module_Id;
   Dynamic_Fixed_Point    : W_Module_Id;
   Static_Floating_Point  : W_Module_Id;
   Dynamic_Floating_Point : W_Module_Id;

   Constr_Arrays                : W_Module_Array (1 .. Max_Array_Dimensions);
   Unconstr_Arrays              : W_Module_Array (1 .. Max_Array_Dimensions);
   Array_Int_Rep_Comparison_Ax  : W_Module_Id;
   Array_BV8_Rep_Comparison_Ax  : W_Module_Id;
   Array_BV16_Rep_Comparison_Ax : W_Module_Id;
   Array_BV32_Rep_Comparison_Ax : W_Module_Id;
   Array_BV64_Rep_Comparison_Ax : W_Module_Id;
   Standard_Array_Logical_Ax    : W_Module_Id;
   Subtype_Array_Logical_Ax     : W_Module_Id;

   --  modules of the _gnatprove_standard.mlw file

   type M_Main_Type is record
      Module            : W_Module_Id;
      Private_Type      : W_Type_Id;
      Null_Extension    : W_Identifier_Id;
      Fixed_Type        : W_Type_Id;
      Bool_Not          : W_Identifier_Id;
      Return_Exc        : W_Name_Id;
      String_Image_Type : W_Type_Id;
      Type_Of_Heap      : W_Type_Id;
      Compat_Tags_Id    : W_Identifier_Id;
   end record;

   type M_Integer_Type is record
      Module  : W_Module_Id;
      Bool_Eq : W_Identifier_Id;
      Bool_Ne : W_Identifier_Id;
      Bool_Le : W_Identifier_Id;
      Bool_Lt : W_Identifier_Id;
      Bool_Ge : W_Identifier_Id;
      Bool_Gt : W_Identifier_Id;
   end record;

   type M_Int_Power_Type is record
      Module : W_Module_Id;
      Power  : W_Identifier_Id;
   end record;

   type M_Int_Div_Type is record
      Module   : W_Module_Id;
      Div      : W_Identifier_Id;
      Euclid   : W_Identifier_Id;
      Rem_Id   : W_Identifier_Id;
      Mod_Id   : W_Identifier_Id;
      Math_Mod : W_Identifier_Id;
   end record;

   type M_Int_Abs_Type is record
      Module : W_Module_Id;
      Abs_Id : W_Identifier_Id;
   end record;

   type M_Int_Minmax_Type is record
      Module : W_Module_Id;
      Min    : W_Identifier_Id;
      Max    : W_Identifier_Id;
   end record;

   type M_Floating_Type is record
      Module       : W_Module_Id;
      Bool_Eq      : W_Identifier_Id;
      Bool_Ne      : W_Identifier_Id;
      Bool_Le      : W_Identifier_Id;
      Bool_Lt      : W_Identifier_Id;
      Bool_Ge      : W_Identifier_Id;
      Bool_Gt      : W_Identifier_Id;
      Max          : W_Identifier_Id;
      Min          : W_Identifier_Id;
      Round_Single : W_Identifier_Id;
      Round_Double : W_Identifier_Id;
      Real_Of_Int  : W_Identifier_Id;
      Round        : W_Identifier_Id;
      Div_Real     : W_Identifier_Id;
      Abs_Real     : W_Identifier_Id;
      Ceil         : W_Identifier_Id;
      Floor        : W_Identifier_Id;
      Power        : W_Identifier_Id;
      Truncate     : W_Identifier_Id;
   end record;

   type M_Boolean_Type is record
      Module          : W_Module_Id;
      Bool_Eq         : W_Identifier_Id;
      Bool_Ne         : W_Identifier_Id;
      Bool_Le         : W_Identifier_Id;
      Bool_Lt         : W_Identifier_Id;
      Bool_Ge         : W_Identifier_Id;
      Bool_Gt         : W_Identifier_Id;
      Andb            : W_Identifier_Id;
      Orb             : W_Identifier_Id;
      Xorb            : W_Identifier_Id;
      Notb            : W_Identifier_Id;
      To_Int          : W_Identifier_Id;
      Of_Int          : W_Identifier_Id;
      Range_Check     : W_Identifier_Id;
      Check_Not_First : W_Identifier_Id;
      Check_Not_Last  : W_Identifier_Id;
      First           : W_Identifier_Id;
      Last            : W_Identifier_Id;
      Value           : W_Identifier_Id;
      Image           : W_Identifier_Id;
      Range_Pred      : W_Identifier_Id;
      Dynamic_Prop    : W_Identifier_Id;
   end record;

   --  Array_Modules, an array of the four modules Array__1 .. Array__4
   --  that should only be used to create the array theories of M_Arrays(_1),
   --  through "Create_Rep_Array_Theory".

   Array_Modules : W_Module_Array (1 .. Max_Array_Dimensions);

   --  symbols common to all arrays

   type M_Array_Type is record
      Module  : W_Module_Id;
      Ty      : W_Type_Id;
      Get     : W_Identifier_Id;
      Set     : W_Identifier_Id;
      Bool_Eq : W_Identifier_Id;
      Slide   : W_Identifier_Id;
   end record;

   --  symbols which only exist for one-dimensional arrays

   type M_Array_1_Type is record
      Module    : W_Module_Id;         --  copy of M_Arrays (1).Module
      Concat    : W_Identifier_Id;
      Singleton : W_Identifier_Id;
   end record;

   --  symbols which only exist for one-dimensional arrays of discrete types

   type M_Array_1_Comp_Type is record
      Module    : W_Module_Id;         --  copy of M_Arrays (1).Module
      Compare   : W_Identifier_Id;
   end record;

   --  symbols which only exist for one-dimensional arrays of boolean types

   type M_Array_1_Bool_Op_Type is record
      Module    : W_Module_Id;         --  copy of M_Arrays (1).Module
      Xorb      : W_Identifier_Id;
      Andb      : W_Identifier_Id;
      Orb       : W_Identifier_Id;
      Notb      : W_Identifier_Id;
   end record;

   type M_BV_Type is record
      Module         : W_Module_Id;
      T              : W_Type_Id;
      Ult            : W_Identifier_Id;
      Ule            : W_Identifier_Id;
      Ugt            : W_Identifier_Id;
      Uge            : W_Identifier_Id;
      Bool_Eq        : W_Identifier_Id;
      Bool_Ne        : W_Identifier_Id;
      Bool_Le        : W_Identifier_Id;
      Bool_Lt        : W_Identifier_Id;
      Bool_Ge        : W_Identifier_Id;
      Bool_Gt        : W_Identifier_Id;
      BV_Min         : W_Identifier_Id;
      BV_Max         : W_Identifier_Id;
      One            : W_Identifier_Id;
      Add            : W_Identifier_Id;
      Sub            : W_Identifier_Id;
      Neg            : W_Identifier_Id;
      Mult           : W_Identifier_Id;
      Power          : W_Identifier_Id;
      To_Int         : W_Identifier_Id;
      Of_Int         : W_Identifier_Id;
      Udiv           : W_Identifier_Id;
      Urem           : W_Identifier_Id;
      BW_And         : W_Identifier_Id;
      BW_Or          : W_Identifier_Id;
      BW_Xor         : W_Identifier_Id;
      BW_Not         : W_Identifier_Id;
      BV_Abs         : W_Identifier_Id;
      Lsl            : W_Identifier_Id;
      Lsr            : W_Identifier_Id;
      Asr            : W_Identifier_Id;
      Rotate_Left    : W_Identifier_Id;
      Rotate_Right   : W_Identifier_Id;
      Two_Power_Size : W_Identifier_Id;
   end record;

   type M_BV_Conv_Type is record
      Module      : W_Module_Id;
      To_Big      : W_Identifier_Id;
      To_Small    : W_Identifier_Id;
      Range_Check : W_Identifier_Id;
   end record;

   M_Main       : M_Main_Type;
   M_Integer    : M_Integer_Type;
   M_Int_Power  : M_Int_Power_Type;
   M_Int_Div    : M_Int_Div_Type;
   M_Int_Abs    : M_Int_Abs_Type;
   M_Int_Minmax : M_Int_Minmax_Type;
   M_Floating   : M_Floating_Type;
   M_Boolean    : M_Boolean_Type;

   --  M_Arrays(_..), are hashed maps of M_Array(_..)_Type indexed by Name_Ids.
   --  The keys are generated by "Get_Array_Theory_Name", and the elements
   --  by "Create_Rep_Array_Theory". An element corresponds to a dynamically
   --  created theory of array used to reason about an ada array with specific
   --  index types, see "Declare_Constrained" and "Declaire_Unconstrained".
   --  These maps are populated by "Create_Rep_Array_Theory_If_Needed",
   --  and can be accessed through "Get_array_Theory(_..)" functions.

   package Name_Id_Array_Map is new Ada.Containers.Hashed_Maps
     (Key_Type        => Name_Id,
      Element_Type    => M_Array_Type,
      Hash            => Common_Containers.Name_Id_Hash,
      Equivalent_Keys => "=");

   M_Arrays : Name_Id_Array_Map.Map;

   package Name_Id_Array_1_Map is new Ada.Containers.Hashed_Maps
     (Key_Type        => Name_Id,
      Element_Type    => M_Array_1_Type,
      Hash            => Common_Containers.Name_Id_Hash,
      Equivalent_Keys => "=");

   M_Arrays_1 : Name_Id_Array_1_Map.Map;

   package Name_Id_Array_1_Comp_Map is new Ada.Containers.Hashed_Maps
     (Key_Type        => Name_Id,
      Element_Type    => M_Array_1_Comp_Type,
      Hash            => Common_Containers.Name_Id_Hash,
      Equivalent_Keys => "=");

   M_Arrays_1_Comp : Name_Id_Array_1_Comp_Map.Map;

   package Name_Id_Array_1_Bool_Op_Map is new Ada.Containers.Hashed_Maps
     (Key_Type        => Name_Id,
      Element_Type    => M_Array_1_Bool_Op_Type,
      Hash            => Common_Containers.Name_Id_Hash,
      Equivalent_Keys => "=");

   M_Arrays_1_Bool_Op : Name_Id_Array_1_Bool_Op_Map.Map;

   M_BV_Conv_32_64 : M_BV_Conv_Type;
   M_BV_Conv_16_64 : M_BV_Conv_Type;
   M_BV_Conv_8_64  : M_BV_Conv_Type;
   M_BV_Conv_16_32 : M_BV_Conv_Type;
   M_BV_Conv_8_32  : M_BV_Conv_Type;
   M_BV_Conv_8_16  : M_BV_Conv_Type;

   type BV_Kind is (BV8, BV16, BV32, BV64);

   M_BVs : array (BV_Kind) of M_BV_Type;

   function MF_BVs (T : W_Type_Id) return M_BV_Type;
   --  same as M_BVs but can be used with a bitvector type in W_Type_Id format
   --  @param T a bitvector type as Why tree node
   --  @return the corresponding Why module record

   --  builtin unary minus

   Int_Unary_Minus           : W_Identifier_Id;
   Fixed_Unary_Minus         : W_Identifier_Id;
   Real_Unary_Minus          : W_Identifier_Id;

   --  built_in void ident

   Void : W_Identifier_Id;

   --  builtin infix symbols

   Why_Eq                    : W_Identifier_Id;
   Why_Neq                   : W_Identifier_Id;
   Int_Infix_Add             : W_Identifier_Id;
   Int_Infix_Subtr           : W_Identifier_Id;
   Int_Infix_Mult            : W_Identifier_Id;
   Int_Infix_Le              : W_Identifier_Id;
   Int_Infix_Ge              : W_Identifier_Id;
   Int_Infix_Gt              : W_Identifier_Id;
   Int_Infix_Lt              : W_Identifier_Id;

   Fixed_Infix_Add           : W_Identifier_Id;
   Fixed_Infix_Subtr         : W_Identifier_Id;
   Fixed_Infix_Mult          : W_Identifier_Id;

   Real_Infix_Add            : W_Identifier_Id;
   Real_Infix_Subtr          : W_Identifier_Id;
   Real_Infix_Mult           : W_Identifier_Id;
   Real_Infix_Lt             : W_Identifier_Id;
   Real_Infix_Le             : W_Identifier_Id;
   Real_Infix_Gt             : W_Identifier_Id;
   Real_Infix_Ge             : W_Identifier_Id;

   To_String_Id              : W_Identifier_Id;
   Of_String_Id              : W_Identifier_Id;

   --  Other identifiers

   Old_Tag                   : Name_Id;
   Def_Name                  : W_Identifier_Id;

   procedure Initialize;
   --  Call this procedure before using any of the entities in this package.

   function E_Module (E : Entity_Id) return W_Module_Id;
   --  this function returns the module where File = No_Name and Name =
   --  Full_Name (E). Memoization may be used. Returns empty when it is called
   --  with a node which is not an entity, and no module is known for this
   --  entity.

   function E_Symb (E : Entity_Id; S : Why_Name_Enum)
                    return W_Identifier_Id;
   --  return the symbol which corresponds to [S] in the Why3 module which
   --  corresponds to E
   --  @param E the Ada type entity
   --  @param S a symbol which is allowed for that type entity

   function E_Axiom_Module (E : Entity_Id) return W_Module_Id;

   procedure Insert_Extra_Module (N : Node_Id; M : W_Module_Id);
   --  After a call to this procedure, E_Module (N) will return M.

   function Init_Array_Module (Module : W_Module_Id) return M_Array_Type;
   function Init_Array_1_Module (Module : W_Module_Id) return M_Array_1_Type;
   function Init_Array_1_Comp_Module (Module : W_Module_Id)
                                      return M_Array_1_Comp_Type;
   function Init_Array_1_Bool_Op_Module (Module : W_Module_Id)
                                      return M_Array_1_Bool_Op_Type;

end Why.Atree.Modules;
