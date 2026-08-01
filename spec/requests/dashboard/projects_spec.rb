require "rails_helper"

RSpec.describe "Dashboard::Projects" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "authentication" do
    it "sends anonymous visitors to the login page for every action" do
      project = create(:project, user: user)

      {
        get: [ dashboard_projects_path, new_dashboard_project_path,
               dashboard_project_path(project), edit_dashboard_project_path(project) ],
        post: [ dashboard_projects_path ],
        patch: [ dashboard_project_path(project) ],
        delete: [ dashboard_project_path(project) ]
      }.each do |verb, paths|
        paths.each do |path|
          public_send(verb, path)

          expect(response).to redirect_to(login_path), "expected #{verb.upcase} #{path} to require sign-in"
        end
      end
    end
  end

  describe "GET /dashboard/projects" do
    it "lists only the signed-in artist's galleries" do
      mine = create(:project, user: user, title: "Mine")
      create(:project, user: other_user, title: "Theirs")
      sign_in_as user

      get dashboard_projects_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end

    it "lists galleries in position order" do
      second = create(:project, user: user, title: "Second", position: 2)
      first = create(:project, user: user, title: "First", position: 1)
      sign_in_as user

      get dashboard_projects_path

      expect(response.body.index(first.title)).to be < response.body.index(second.title)
    end
  end

  describe "POST /dashboard/projects" do
    before { sign_in_as user }

    it "creates a gallery owned by the signed-in artist" do
      expect do
        post dashboard_projects_path, params: { project: { title: "Blue Period" } }
      end.to change(user.projects, :count).by(1)

      project = user.projects.last
      expect(project.title).to eq("Blue Period")
      expect(project.slug).to eq("blue-period")
      expect(response).to redirect_to(dashboard_project_path(project))
    end

    it "creates galleries as drafts" do
      post dashboard_projects_path, params: { project: { title: "Quiet Work" } }

      expect(user.projects.last).not_to be_published
    end

    it "ignores an attempt to assign the gallery to someone else" do
      post dashboard_projects_path, params: { project: { title: "Sneaky", user_id: other_user.id } }

      expect(user.projects.last.title).to eq("Sneaky")
      expect(other_user.projects).to be_empty
    end

    it "rejects a blank title" do
      expect do
        post dashboard_projects_path, params: { project: { title: "" } }
      end.not_to change(Project, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /dashboard/projects/:id" do
    it "finds the gallery by slug" do
      project = create(:project, user: user, title: "Sketchbook")
      sign_in_as user

      get dashboard_project_path(project)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sketchbook")
    end

    # 404 rather than 403 on purpose: a "forbidden" would confirm the gallery
    # exists. The scoped lookup makes someone else's slug indistinguishable from
    # a slug that was never taken.
    it "404s on another artist's gallery rather than confirming it exists" do
      theirs = create(:project, user: other_user, title: "Private Work")
      sign_in_as user

      get dashboard_project_path(theirs)
      response_for_real_slug = response.status

      get "/dashboard/projects/a-slug-nobody-has"

      expect(response_for_real_slug).to eq(404)
      expect(response.status).to eq(response_for_real_slug)
    end
  end

  describe "PATCH /dashboard/projects/:id" do
    it "updates the artist's own gallery" do
      project = create(:project, user: user, title: "Before")
      sign_in_as user

      patch dashboard_project_path(project), params: { project: { title: "After", published: "1" } }

      expect(project.reload.title).to eq("After")
      expect(project).to be_published
    end

    it "refuses to update another artist's gallery" do
      project = create(:project, user: other_user, title: "Untouched")
      sign_in_as user

      patch dashboard_project_path(project), params: { project: { title: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(project.reload.title).to eq("Untouched")
    end

    it "rejects an invalid slug" do
      project = create(:project, user: user)
      sign_in_as user

      patch dashboard_project_path(project), params: { project: { slug: "not a slug" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /dashboard/projects/:id" do
    it "deletes the artist's own gallery" do
      project = create(:project, user: user)
      sign_in_as user

      expect { delete dashboard_project_path(project) }.to change(user.projects, :count).by(-1)

      expect(response).to redirect_to(dashboard_projects_path)
    end

    it "refuses to delete another artist's gallery" do
      project = create(:project, user: other_user)
      sign_in_as user

      expect { delete dashboard_project_path(project) }.not_to change(Project, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
