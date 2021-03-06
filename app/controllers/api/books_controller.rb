class Api::BooksController < ApplicationController
	before_action :authenticate_user!
	before_action :check_if_approved, only: [:subscribe]
	
	def show
		category = Category.find(params[:category_id])
		book = category.books.find(params[:id]).to_json
		book_hash = JSON.parse(book)
		book_hash["category"] = category.name
		render json: {book: [book_hash]}
	end

	def subscribe
		@book = Book.find(params[:id])
		if @book.available
			unless current_user.current_round == 0
				current_user.current_round_decrement
				@book.subscriber_id = current_user.id
				@book.borrow_date = Date.today
				@book.approved = false
				@book.available = false
				if @book.save
					render status: 200, json:{
						message: ["تم حجز الكتاب بنجاح"]
					}.to_json
				end
			else
				render status: 401, json:{
					error: ["لقد تجاوزت الحد المسموح به لحجز الكتب"] 
					}.to_json
			end
		else
			render status: 401, json:{
				error: ["الكتاب غير متوفر"] 
				}.to_json
		end
	end

	def unsubscribe
		@book = Book.find(params[:id])
		unless @book.available
			current_user.current_round_increment
			@book.subscriber_id = nil
			@book.borrow_date = nil
			@book.approved = nil
			@book.available = true
			if @book.save
				render status: 200, json:{
					message: ["تم إلغاء حجز الكتاب"]
				}.to_json
			end
		end
	end

	def search
		response = []
		result = Book.search_by_name(params[:search])
		result.each do |r|
			result_hash = {name: r.name, url: "api/categories/#{r.category_id}/books/#{r.id}"}
			response.push(result_hash)
		end
		render json: {result: response}
	end

	def create
		@category = Category.find(params[:category_id])
		@book = @category.books.build(book_params)
		if @book.save
			render status: 200, json:{
					message: "book created successfully!",
					book: [@book]
				}.to_json
		else
			head 403
		end
	end

	def update
		@category = Category.find(params[:category_id])
		@book = @category.books.build(book_params)
		if @book.update(book_params)
			render status: 200, json:{
					message: "book updated successfully!",
					book: [@book]
				}.to_json
		else
			head 403
		end
	end

	def destroy
		@category = Category.find(params[:category_id])
		@book = @category.books.find(params[:id])
		if @book.destroy
			render status: 200, json:{
					message: "book deleted successfully!"
				}.to_json
		else
			render status: 401, json:{
					errors: [@book.errors]
				}.to_json
		end
	end

	def most_borrowed
		if current_user.borrow_group == "A"
			most_borrowed_books = Book.where(group: "A").order(borrow_times: "DESC").limit(15).to_a
		elsif current_user.borrow_group == "B"
			most_borrowed_books = Book.where(group: ['A','B']).order(borrow_times: "DESC").limit(15).to_a
		elsif current_user.borrow_group == "C"
			most_borrowed_books = Book.order(borrow_times: "DESC").limit(15).to_a
		end	
		render json: {books: most_borrowed_books}
	end

	def favorite_books
		category_id = Category.where(name: current_user.favorite_book_type).first
		if current_user.borrow_group == "A"
			favorite_books = Book.where({category_id: category_id, group: "A"}).order(borrow_times: "DESC").limit(15).to_a
		elsif current_user.borrow_group == "B"
			favorite_books = Book.where({category_id: category_id, group: ['A','B']}).order(borrow_times: "DESC").limit(15).to_a
		elsif current_user.borrow_group == "C"
			favorite_books = Book.where(category_id: category_id).order(borrow_times: "DESC").limit(15).to_a
		end	
			
		render json: {books: favorite_books}
	end

	private
	def book_params
		params.require("book").permit(:book_id,:name,:author,:translator,:num_of_pages,:page_size,:publishing_house,:group,:owner_id,:category_id,:sub_category_id,:available)
	end

	protected
	def check_if_approved
	    unless current_user.approved
	      render status: 403, json:{
					error: ["انتظر تفعيل الحساب من الإدارة"]
				}.to_json
	    end
 	end
end