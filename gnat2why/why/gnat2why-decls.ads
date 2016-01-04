------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                         G N A T 2 W H Y - D E C L S                      --
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

with Common_Containers; use Common_Containers;
with Gnat2Why.Util;     use Gnat2Why.Util;
with Types;             use Types;

package Gnat2Why.Decls is

   procedure Translate_Abstract_State
     (File : in out Why_Section;
      E    : Entity_Id);
   --  Generate Why declarations that correspond to an abstract state

   procedure Translate_Variable
     (File : in out Why_Section;
      E    : Entity_Id);
   --  Generate Why declarations that correspond to an Ada top level object
   --  declaration

   procedure Translate_Constant
     (File : in out Why_Section;
      E    : Entity_Id);
   --  Generate a function declaration for IN parameters, named numbers and
   --  constant objects.

   procedure Translate_Constant_Value
     (File : in out Why_Section;
      E    : Entity_Id);
   --  Possibly generate an axiom to define the value of the function
   --  previously declared by a call to Translate_Constant, for IN
   --  parameters, named numbers and constant objects.

   procedure Translate_External_Object (E : Entity_Name);
   --  For a "magic string" generate a dummy declaration module which contains
   --  the type and the variable declaration.

   procedure Translate_Loop_Entity
     (File : in out Why_Section;
      E    : Entity_Id);

end Gnat2Why.Decls;
