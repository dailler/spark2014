-- copyright 2012 David MENTR� <dmentre@linux-france.org>

--  Permission is hereby granted, free of charge, to any person or organization
--  obtaining a copy of the software and accompanying documentation covered by
--  this license (the "Software") to use, reproduce, display, distribute,
--  execute, and transmit the Software, and to prepare derivative works of the
--  Software, and to permit third-parties to whom the Software is furnished to
--  do so, all subject to the following:
--
--  The copyright notices in the Software and this entire statement, including
--  the above license grant, this restriction and the following disclaimer,
--  must be included in all copies of the Software, in whole or in part, and
--  all derivative works of the Software, unless such copies or derivative
--  works are solely in the form of machine-executable object code generated by
--  a source language processor.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
--  SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
--  FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
--  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
--  DEALINGS IN THE SOFTWARE.

with Ada.Text_Io;
use Ada.Text_Io;
with Ada.Assertions;
use Ada.Assertions;

package body eVoting is

   CANDIDATES_FILENAME : constant String := "candidates.txt";

   procedure Read_Candidates(program_phase : Program_Phase_t;
                             candidates : out Candidate_Name_Array_t;
                             last_candidate : out Candidate_Number_t) is
      file : File_Type;
      current_candidate : Candidate_Number_t := Candidate_Number_t'First + 1;
      last : Natural;
      item : Candidate_Name_t;
   begin
      Assert(program_phase = Setup_Phase);

      -- initialize 'candidates' with spaces
      for i in candidates'Range loop
         for j in Candidate_Name_t'Range loop
            candidates(i)(j) := ' ';
         end loop;
      end loop;

      -- populate 'candidates' with content of CANDIDATES_FILENAME
      candidates(candidates'First)(NO_VOTE_ENTRY'Range) := NO_VOTE_ENTRY;
      Open(File => file, Mode => In_File, Name => CANDIDATES_FILENAME);

      while not(End_Of_File(file))
            and current_candidate < candidates'Last loop
         Get_Line(File => file, Item => item, Last => last);
         candidates(current_candidate)(1..last) := item(1..last);

         current_candidate := current_candidate + 1;
      end loop;

      Close(file);
      last_candidate := current_candidate - 1;
      return;
   end Read_Candidates;

   procedure Print_A_Candidate(candidates : Candidate_Name_Array_t;
                               candidate_id : Candidate_Number_t) is
   begin
         Put(Candidate_Number_t'Image(candidate_id));
         Put(". ");
         Put(candidates(candidate_id));
   end Print_A_Candidate;

   procedure Print_Candidates(candidates : Candidate_Name_Array_t;
                              last_candidate : Candidate_Number_t) is
   begin
      for i in 0..last_candidate loop
         Put("    ");
         Print_A_Candidate(candidates, i);
         Put_Line("");
      end loop;
   end Print_Candidates;

   procedure Vote_Setup(program_phase : Program_Phase_t;
                        candidates : out Candidate_Name_Array_t;
                        last_candidate : out Candidate_Number_t) is
   begin
      Put_Line("**** Vote Setup ****");
      Put("* reading candidates file '");
      Put(CANDIDATES_FILENAME);
      Put_Line("'");

      Read_Candidates(program_phase, candidates, last_candidate);

      Put(Candidate_Number_t'Image(last_candidate));
      Put_Line(" candidates:");
      Print_Candidates(candidates, last_candidate);
   end Vote_Setup;

   procedure Get_Vote(program_phase : Program_Phase_t;
                      candidates : Candidate_Name_Array_t;
                      last_candidate : Candidate_Number_t;
                      chosen_vote : out Candidate_Number_t) is
      buf : String(1..10);
      last : Natural;
      choice : Candidate_Number_t;
   begin
      Assert(program_phase = Voting_Phase);

      loop
         begin
            Put_Line("Chose a candidate:");
            Print_Candidates(candidates, last_candidate);
            Put("Your choice (0-");
            Put(Candidate_Number_t'Image(last_candidate));
            Put_Line(")");

            Get_Line(buf, last);
            choice := Candidate_Number_t'Value(buf(1..last));
            if choice <= last_candidate then
               Put("Are you sure your vote ");
               Print_A_Candidate(candidates, choice);
               Put_Line(" is correct (y/n)?");

               Get_Line(buf, last);
               if buf(1) = 'y' or buf(1) = 'Y' then
                  chosen_vote := choice;
                  return;
               else
                  Put_Line("Vote canceled, redo");
               end if;
            else
               raise Constraint_Error;
            end if;

         exception when Constraint_Error =>
            Put("Invalid choice (");
            Put(Candidate_Number_t'Image(choice));
            Put_Line("), redo");
         end;
      end loop;
   end Get_Vote;

   function Counters_Sum(counters : in Counters_t) return Natural is
      sum : Natural := 0;
   begin
      for i in Counters_t'Range loop
         pragma Loop_Invariant((sum <= Natural(Counter_Range_t'Last) * Natural(i))
                       and
                         (counters(i) <= Counter_Range_t'Last)
                       and
                      (i in Counters_t'Range));
         sum := sum + Natural(counters(i));
      end loop;
      return sum;
   end;

   procedure Voting(program_phase : Program_Phase_t;
                    candidates : in Candidate_Name_Array_t;
                    last_candidate : in Candidate_Number_t;
                    counters : in out Counters_t;
                    number_of_votes : in out Natural) is
      buf : String(1..255);
      last : Natural;
      chosen_vote : Candidate_Number_t;
   begin
      Put_Line("**** Voting ****");

      while number_of_votes < Natural(last_candidate * Counters_t'Last) loop
         Put_Line("Do you want to vote or stop the vote (v/'end of vote')?");
         Get_Line(Item => buf, Last => last);
         if buf(1) = 'v' then
            Get_Vote(program_phase, candidates, last_candidate, chosen_vote);

            if counters(chosen_vote) < Counter_Range_t'Last then
               counters(chosen_vote) := counters(chosen_vote) + 1;
               number_of_votes := number_of_votes + 1;
               Put("Vote stored: ");
               Print_A_Candidate(candidates, chosen_vote);
               Put_Line("");
            else
               return;
            end if;

         elsif buf(1..11) = "end of vote" then
            return;
         end if;
      end loop;
   end Voting;

   procedure Compute_Winner(program_phase : Program_Phase_t;
                            last_candidate : in Candidate_Number_t;
                            counters : in Counters_t;
                            winners : out Election_Result_t) is
      latest_highest_score : Candidate_Number_t;
   begin
      Assert(program_phase = Counting_Phase);

      -- "No vote" is NOT taken into account
      winners(Candidate_Number_t'First) := False;

      latest_highest_score := Candidate_Number_t'First + 1;
      winners(latest_highest_score) := True;

      for i in (Candidate_Number_t'First + 2)..last_candidate loop
         pragma Loop_Invariant
           (winners(Candidate_Number_t'First) = False and then
            Latest_Highest_Score < I and then
            Winners(Latest_Highest_Score) and then
              (for all J in Candidate_Number_T
               range (Candidate_Number_T'First + 1) .. I-1 =>
                 (if J > Latest_Highest_Score then
                    (Counters(Latest_Highest_Score) > Counters(J))))
           and then
              (for all J in Candidate_Number_T
               range (Candidate_Number_T'First + 1) .. I - 1 =>
                 (if Winners(J) then
                  Counters(Latest_Highest_Score) = Counters(J)
                  else
                  Counters(Latest_Highest_Score) > Counters(J))));
         if counters(i) > counters(latest_highest_score) then
            for J in Candidate_Number_T'First..I - 1 loop
               pragma Loop_Invariant
                 (for all K in Candidate_Number_T range 0 .. J - 1 =>
                  not Winners(K));
               Winners(J) := False;
            end loop;
            winners(i) := True;
            latest_highest_score := i;
         elsif counters(i) = counters(latest_highest_score) then
            winners(i) := True;
            latest_highest_score := i;
         else
            winners(i) := False;
         end if;
      end loop;

      declare
         Init_Winners : Election_Result_T := Winners;
      begin
         for I in (Last_Candidate + 1)..Candidate_Number_T'Last loop
            pragma Loop_Invariant ((for all J in (Last_Candidate + 1)..I-1
              => not Winners(J)) and
                (for all J in Candidate_Number_T'First..Last_Candidate
                 => Winners(J) = Init_Winners(J)));
            Winners(I) := False;
         end loop;
      end;
   end Compute_Winner;

   procedure Compute_Print_Results(program_phase : Program_Phase_t;
                                   candidates : in Candidate_Name_Array_t;
                                   last_candidate : in Candidate_Number_t;
                                   counters : in Counters_t) is
      total : Total_Range_t := 0;
      valid_total : Total_Range_t; -- votes different from "No vote"
      winners : Election_Result_t;
   begin
      Put_Line("**** Result ****");

      for i in 0..last_candidate loop
         Pragma Assert((if i > 0 then total >= Total_Range_t(counters(0)))
                       and
                         (last_candidate <= Candidate_Number_t'Last)
                       and
                         (i in Candidate_Number_t'Range)
                       and
                       (total <= Total_Range_t(i) * Total_Range_t(Counter_Range_t'Last)));
         total := total + Total_Range_t(counters(i));
      end loop;

      valid_total := total - Total_Range_t(counters(0));

      for i in 0..last_candidate loop
         Put(Counter_Range_t'Image(counters(i)));
         Put(" vote(s): ");
         Print_A_Candidate(candidates, i);
         Put_Line("");
      end loop;

      Put("Total number of votes: ");
      Put(Total_Range_t'Image(total));
      Put_Line("");

      Put("Total number of valid votes: ");
      Put(Total_Range_t'Image(valid_total));
      Put_Line("");

      Compute_Winner(program_phase, last_candidate, counters, winners);

      Put_Line("* Winner(s) ");
      for i in Candidate_Number_t'Range loop
         if winners(i) then
            Print_A_Candidate(candidates, i);
            Put_Line("");
         end if;
      end loop;
   end Compute_Print_Results;

   procedure Do_Vote is
      candidates : Candidate_Name_Array_t; -- := (others => "--undefined--");
      counters : Counters_t := (others => 0);
      last_candidate : Candidate_Number_t := 0;
      number_of_votes : Natural := 0;
   begin
      Put_Line("**** Start of evoting program (Ada version) ****");

      Vote_Setup(Setup_Phase, candidates, last_candidate);

      Voting(Voting_Phase, candidates, last_candidate, counters, number_of_votes);

      Compute_Print_Results(Counting_Phase, candidates, last_candidate, counters);
   end Do_Vote;

end eVoting;
