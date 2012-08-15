module TicGitNG
  module Command
    module Init
      def parser o
        o.banner= "Usage: ti init"
      end
      def execute
        @tic.read_tickets
=begin
        #Initialization has to happen earlier in the code so this code stands
        #as an example, when `ti init` is called, initialization is handled by
        #base.rb:354 (at the time of writing this).
        tic.base.init_ticgitng_branch(
          git.lib.branches_all.map{|b| b.first }.include?(which_branch?)
        )
=end
      end
    end
  end
end
