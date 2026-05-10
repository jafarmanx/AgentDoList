class Account::Seeder
  attr_reader :account, :creator

  def initialize(account, creator)
    @account = account
    @creator = creator
  end

  def seed
    Current.set(user: creator, account: account) do
      populate
    end
  end

  def seed!
    raise "You can't run in production environments" unless Rails.env.local?

    delete_everything
    seed
  end

  private
    def populate
      # ---------------
      # Playground Board
      # ---------------
      # ---------------
      # Default Agents
      # ---------------
      developer = account.agents.create! name: "Developer", role_description: "Full-stack developer", personality: "Methodical and detail-oriented. Writes clean, well-tested code.", system_prompt: "You are a senior full-stack developer. Write clean, maintainable code with tests."
      developer.add_skill "Ruby on Rails", proficiency: "expert"
      developer.add_skill "JavaScript", proficiency: "advanced"
      developer.add_skill "SQL", proficiency: "advanced"

      designer = account.agents.create! name: "Designer", role_description: "UI/UX designer", personality: "Creative and user-focused. Prioritizes clarity and simplicity.", system_prompt: "You are a UI/UX designer. Focus on clean, intuitive interfaces."
      designer.add_skill "UI Design", proficiency: "expert"
      designer.add_skill "CSS", proficiency: "expert"
      designer.add_skill "Accessibility", proficiency: "advanced"

      reviewer = account.agents.create! name: "Reviewer", role_description: "Code reviewer and QA", personality: "Thorough and constructive. Catches bugs before they ship.", system_prompt: "You are a code reviewer and QA specialist. Review code for correctness, security, and maintainability."
      reviewer.add_skill "Code Review", proficiency: "expert"
      reviewer.add_skill "Testing", proficiency: "expert"
      reviewer.add_skill "Security", proficiency: "advanced"

      playground = account.boards.create! name: "Playground", creator: creator, all_access: true
      playground.update! auto_postpone_period: 365.days

      # Cards
      playground.cards.create! creator: creator, title: “Grab the invite link to invite someone else”, status: “published”, description: <<~HTML
        <p>Open the CurioArch menu, select “<b><strong>+ Add people</b></strong>”, then copy the invite link. You can give this link to someone else so they can make a login for themselves in your account.</p>
      HTML

      playground.cards.create! creator: creator, title: “Head back home to check out activity”, status: “published”, description: <<~HTML
        <p>Hit “1” or pull down the CurioArch menu and select “Home”.</p>
      HTML

      playground.cards.create! creator: creator, title: “Check out all cards assigned to you”, status: “published”, description: <<~HTML
        <p>Pull down the CurioArch menu at the top of the screen, and select “<b><strong>Assigned to me</b></strong>” or just hit “2” on your keyboard any time.</p>
      HTML

      playground.cards.create! creator: creator, title: “Open the CurioArch menu”, status: “published”, description: <<~HTML
        <p>The CurioArch menu is how you get around the app. Click “<b><strong>CurioArch</b></strong>” at the top of the screen or hit the “J” key on your keyboard to pop it open.</p>
      HTML

      playground.cards.create! creator: creator, title: “Assign this card to yourself”, status: “published”, description: <<~HTML
        <p>Click the little head with the + next to it, then pick yourself.</p>
      HTML

      playground.cards.create! creator: creator, title: “Tag this card “Design” then move it to YES”, status: “published”, description: <<~HTML
        <p>Click the little Tag icon, type “design”, then “<b><strong>Create tag</b></strong>”. Then, move the card to the new “YES” column you created in the previous step.</p>
      HTML

      playground.cards.create! creator: creator, title: “Make two more columns”, status: “published”, description: <<~HTML
        <ol>
          <li>Make one called “Yes”</li>
          <li>Make another called “Working on”</li>
        </ol>
        <p>Go back to the Board view, click the little “+” to the right of the DONE column, name the column, pick a color, then do it again.</p>
        <p>After that, drag this card to “DONE” or select “DONE” in the sidebar.</p>
      HTML

      playground.cards.create! creator: creator, title: “Move this card to NOT NOW”, status: “published”, description: <<~HTML
        <p>You can either select “NOT NOW” over in the sidebar, or you can go back out to the board view and drag this card into the “NOT NOW” column on the left side.</p>
      HTML

      playground.cards.create! creator: creator, title: “Rename this card”, status: “published”, description: <<~HTML
        <ol>
          <li>Click the title and you can rename the card, change the description, or add more information to the card.</li>
          <li>Then, hit “Mark as Done” at the bottom of the card.</li>
          <li>Finally, hit “<b><strong>Back to Playground</strong></b>” in the top left of the screen to go back to the board.</li>
        </ol>
      HTML
    end

    def delete_everything
      Current.set(user: creator, account: account) do
        account.boards.destroy_all
      end
    end
end
