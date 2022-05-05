class AbExperiment
  # Responsible for checking if a given :user has "accomplished" the state :goal for any of the
  # active :experiments.  We scope our tests to events that happened on or after the experiment's
  # start date.
  #
  # @note It is required that each experiment have a start date (in CCYY-MM-DD format).
  class GoalConversionHandler
    include FieldTest::Helpers

    USER_CREATES_PAGEVIEW_GOAL = "user_creates_pageview".freeze
    USER_CREATES_COMMENT_GOAL = "user_creates_comment".freeze

    def self.call(...)
      new(...).call
    end

    def initialize(user:, goal:, experiments:)
      @user = user
      @goal = goal
      @experiments = experiments
    end

    attr_reader :experiments, :user, :goal

    def call
      # It's okay that there are no experiments.
      return if experiments.nil?

      experiments.each do |key, data|
        experiment_start_date = data.fetch("start_date").beginning_of_day
        experiment = key.to_sym
        convert(experiment: experiment, experiment_start_date: experiment_start_date)
      end
    end

    private

    def convert(experiment:, experiment_start_date:)
      case goal
        # We have special conditional goals for some where we look for past events for cummulative wins
        # Otherwise we convert the goal as given.
      when USER_CREATES_PAGEVIEW_GOAL
        pageview_goal(experiment,
                      [7.days.ago, experiment_start_date].max,
                      "DATE(created_at)",
                      4,
                      "user_views_pages_on_at_least_four_different_days_within_a_week")
        pageview_goal(experiment,
                      [24.hours.ago, experiment_start_date].max,
                      "DATE_PART('hour', created_at)",
                      4,
                      "user_views_pages_on_at_least_four_different_hours_within_a_day")
        pageview_goal(experiment,
                      [14.days.ago, experiment_start_date].max,
                      "DATE(created_at)",
                      9,
                      "user_views_pages_on_at_least_nine_different_days_within_two_weeks")
        pageview_goal(experiment,
                      [5.days.ago, experiment_start_date].max,
                      "DATE_PART('hour', created_at)",
                      12,
                      "user_views_pages_on_at_least_twelve_different_hours_within_five_days")
      when USER_CREATES_COMMENT_GOAL # comments goal. Only page views and comments are currently active.
        field_test_converted(experiment, participant: user, goal: goal) # base single comment goal.
        comment_goal(experiment,
                     [7.days.ago, experiment_start_date].max,
                     "DATE(created_at)",
                     4,
                     "user_creates_comment_on_at_least_four_different_days_within_a_week")
      else
        field_test_converted(experiment, participant: user, goal: goal) # base single comment goal.
      end
    end

    def pageview_goal(experiment, time_start, group_value, min_count, goal)
      page_view_counts = user.page_views.where("created_at > ?", time_start)
        .group(group_value).count.values
      page_view_counts.delete(0)
      return unless page_view_counts.size >= min_count

      field_test_converted(experiment, participant: user, goal: goal)
    end

    def comment_goal(experiment, time_start, group_value, min_count, goal)
      comment_counts = user.comments.where("created_at > ?", time_start)
        .group(group_value).count.values
      comment_counts.delete(0)
      return unless comment_counts.size >= min_count

      field_test_converted(experiment, participant: user, goal: goal)
    end
  end
end