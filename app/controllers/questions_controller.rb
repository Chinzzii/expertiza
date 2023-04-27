class QuestionsController < ApplicationController
  include AuthorizationHelper

  # A question is a single entry within a questionnaire
  # Questions provide a way of scoring an object
  # based on either a numeric value or a true/false
  # state.

  # Default action, same as list
  def index
    list
    render action: 'list'
  end

  def action_allowed?
    current_user_has_ta_privileges?
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify method: :post, only: %i[destroy create update],
         redirect_to: { action: :list }

  # List all questions in paginated view
  def list
    @questions = Question.paginate(page: params[:page], per_page: 10)
  end

  # Display a given question
  def show
    @question = Question.find(params[:id])
  end

  # Provide the user with the ability to define
  # a new question
  def new
    @question = Question.new
  end

  # Save a question created by the user
  # follows from new
  def create
    @question = Question.new(question_params[:question])
    if @question.save
      flash[:notice] = 'The question was successfully created.'
      redirect_to action: 'list'
    else
      render action: 'new'
    end
  end

  # edit an existing question
  def edit
    @question = Question.find(params[:id])
  end

  # save the update to an existing question
  # follows from edit
  def update
    @question = Question.find(question_params[:id])
    if @question.update_attributes(question_params[:question])
      flash[:notice] = 'The question was successfully updated.'
      redirect_to action: 'show', id: @question
    else
      render action: 'edit'
    end
  end

  # Remove question from database and
  # return to list
  def destroy
    question = Question.find(params[:id])
    questionnaire_id = question.questionnaire_id

    if AnswerHelper.check_and_delete_responses(questionnaire_id)
      flash[:success] = 'You have successfully deleted the question. Any existing reviews for the questionnaire have been deleted!'
    else
      flash[:success] = 'You have successfully deleted the question!'
    end

    begin
      question.destroy
    rescue StandardError
      flash[:error] = $ERROR_INFO
    end
    redirect_to edit_questionnaire_path(questionnaire_id.to_s.to_sym)
  end

  # required for answer tagging
  def types
    types = Question.distinct.pluck(:type)
    render json: types.to_a
  end

  # save questions that have been added to a questionnaire
  def save_new_questions
    questionnaire_id = params[:questionnaire_id]
    questionnaire_type = params[:questionnaire_type]
    if params[:new_question]
      # The new_question array contains all the new questions
      # that should be saved to the database
      params[:new_question].keys.each_with_index do |question_key, index|
        q = Question.new
        q.txt = params[:new_question][question_key]
        q.questionnaire_id = questionnaire_id
        q.type = params[:question_type][question_key][:type]
        q.seq = question_key.to_i
        if questionnaire_type == 'QuizQuestionnaire'
          # using the weight user enters when creating quiz
          weight_key = "question_#{index + 1}"
          q.weight = params[:question_weights][weight_key.to_sym]
        end
        q.save unless q.txt.strip.empty?
      end
    end
    redirect_to request.original_url
  end

  private

  def question_params
    params.permit(:id, :question)
  end
end

