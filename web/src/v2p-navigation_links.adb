------------------------------------------------------------------------------
--                              Vision2Pixels                               --
--                                                                          --
--                           Copyright (C) 2007                             --
--                      Pascal Obry - Olivier Ramonat                       --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.       --
------------------------------------------------------------------------------

with AWS.Templates;

with V2P.Context;
with V2P.Database;
with V2P.Template_Defs.Set_Global;

package body V2P.Navigation_Links is

   use AWS.Services.Web_Block.Context;

   Navigation_Links_Name : constant String := "Navigation_Links";

   package Links is
     new Generic_Data (Data      => Post_Ids.Vector,
                       Null_Data => Post_Ids.Empty_Vector);
   --  Adds Post_Ids.Vector to context value data

   procedure Load_Pages
     (Context   : access Services.Web_Block.Context.Object;
      Page_Size : in     Positive;
      From      : in     Positive);
   --  Load post ids in context
   --  If Previous_Id or Next_Id are null, check if it is possible
   --  to retrieve further ids according to the current filter

   ----------------
   -- Load_Pages --
   ----------------

   procedure Load_Pages
     (Context   : access Services.Web_Block.Context.Object;
      Page_Size : in     Positive;
      From      : in     Positive)
   is
      Admin     : constant Boolean :=
                    Context.Exist (Template_Defs.Set_Global.ADMIN)
                  and then Context.Get_Value
                    (Template_Defs.Set_Global.ADMIN) = "TRUE";
      Nav_From  : Positive := From;
      Nav_Links : Post_Ids.Vector;
      Set       : AWS.Templates.Translate_Set;
      Nb_Lines  : Natural;
      Total     : Natural;
   begin
      Database.Get_Threads
        (FID         => V2P.Context.Counter.Get_Value
           (Context => Context.all,
            Name    => Template_Defs.Set_Global.FID),
         From        => Nav_From,
         Admin       => Admin,
         Filter      => Database.Filter_Mode'Value (Context.Get_Value
           (Template_Defs.Set_Global.FILTER)),
         Filter_Cat  => Context.Get_Value
           (Template_Defs.Set_Global.FILTER_CATEGORY),
         Page_Size   => Page_Size,
         Order_Dir   => Database.Order_Direction'Value
           (Context.Get_Value (Template_Defs.Set_Global.ORDER_DIR)),
         Navigation  => Nav_Links,
         Set         => Set,
         Nb_Lines    => Nb_Lines,
         Total_Lines => Total);

      Links.Set_Value (Context => Context.all,
                       Name    => Navigation_Links_Name,
                       Value   => Nav_Links);

      V2P.Context.Not_Null_Counter.Set_Value
        (Context => Context.all,
         Name    => Template_Defs.Set_Global.NAV_FROM,
         Value   => Nav_From);

      V2P.Context.Counter.Set_Value
        (Context => Context.all,
         Name    => Template_Defs.Set_Global.NAV_NB_LINES_RETURNED,
         Value   => Nb_Lines);

      V2P.Context.Counter.Set_Value
        (Context => Context.all,
         Name    => Template_Defs.Set_Global.NAV_NB_LINES_TOTAL,
         Value   => Total);
   end Load_Pages;

   ---------------
   -- Next_Post --
   ---------------

   function Next_Post
     (Context : access Services.Web_Block.Context.Object;
      Id      : in Positive) return Natural
   is
      use Post_Ids;
      use Template_Defs;
      Posts   : constant Vector :=
                  Links.Get_Value
                    (Context => Context.all,
                     Name    => Navigation_Links_Name);
      Current : Cursor := Find (Posts, Id);
   begin
      if Current = No_Element then
         return 0;
      end if;

      Next (Current);

      if Current /= No_Element then
         return Element (Current);
      else
         --  Try harder to find next post id

         declare
            Page_Size : constant Navigation_Links.Page_Size :=
                          V2P.Context.Not_Null_Counter.Get_Value
                            (Context => Context.all,
                             Name    => Set_Global.FILTER_PAGE_SIZE);
            Total     : constant Natural := V2P.Context.Counter.Get_Value
              (Context => Context.all,
               Name    => Template_Defs.Set_Global.NAV_NB_LINES_TOTAL);
            Nav_From  : constant Positive :=
                          V2P.Context.Not_Null_Counter.Get_Value
                            (Context => Context.all,
                             Name    => Set_Global.NAV_FROM);
         begin
            if Nav_From + Page_Size < Total then
               --  Fetch more post ids
               Load_Pages (Context   => Context,
                           From      => Nav_From,
                           Page_Size => Page_Size * 2);

               --  Recursive call to Next_Post as the next element has been
               --  loaded in Links

               return Next_Post (Context => Context,
                                 Id      => Id);
            else
               --  End of post ids list. Abort

               return 0;
            end if;
         end;
      end if;
   end Next_Post;

   -------------------
   -- Previous_Post --
   -------------------

   function Previous_Post
     (Context : access Services.Web_Block.Context.Object;
      Id      : in Positive) return Natural
   is
      use Post_Ids;
      use Template_Defs;
      Posts   : constant Vector :=
                  Links.Get_Value
                    (Context => Context.all,
                     Name    => Navigation_Links_Name);

      Current : Cursor := Find (Posts, Id);
   begin
      if Current = No_Element then
         return 0;
      end if;

      Previous (Current);

      if Current /= No_Element then
         return Element (Current);
      else

         --  Try harder to find previous post id

         declare
            Page_Size : constant Navigation_Links.Page_Size :=
                          V2P.Context.Not_Null_Counter.Get_Value
                            (Context => Context.all,
                             Name    => Set_Global.FILTER_PAGE_SIZE);
            Nav_From  : Positive :=
                          V2P.Context.Not_Null_Counter.Get_Value
                            (Context => Context.all,
                             Name    => Set_Global.NAV_FROM);
         begin

            if Nav_From /= 1 then

               if Nav_From > Page_Size then
                  Nav_From := Nav_From - Page_Size;
               else
                  Nav_From := 1;
               end if;

               --  Fetch more post ids
               Load_Pages (Context   => Context,
                           From      => Nav_From,
                           Page_Size => Page_Size * 2);

               --  Recursive call to Previous_Post as the previous element
               --  has been loaded in Links

               return Previous_Post (Context => Context,
                                     Id      => Id);
            else
               --  Begin of post ids list. Abort

               return 0;
            end if;
         end;
      end if;
   end Previous_Post;

   procedure Set
     (Context : access Services.Web_Block.Context.Object;
      Posts   : in Post_Ids.Vector)
   is
   begin
      Links.Set_Value (Context => Context.all,
                       Name    => Navigation_Links_Name,
                       Value   => Posts);
   end Set;


end V2P.Navigation_Links;