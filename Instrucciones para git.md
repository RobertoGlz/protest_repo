Instrucciones para git

1. Create an Issue in Github
	- Issues -> New Issue
		- Choose an informative title and write a description of the tasks to be done in the issue.
		- Choose an assignee

		- The assignee will write a description of what was done in the issue and write the paths to the relevant codes and outputs.
		- The assignee is responsible for closing the issue once the issue has been declared "Accomplished" or "Not Accomplished" by all collaborators. 

2. Create a branch in the local repository
	- In git terminal: `cd Path/to/local/repository`
					   `git status` (It should say "On branch main"; if you type `git branch` you'll see only the main branch exists)
	- Create a new branch typing: `git checkout -b issue#n_nameofissue` where #n is the number of the issue, and nameofissue is the name given to the issue

	- **NOTE:** You could now move between branches typing `git checkout nameofbranch`

	- Do all the work on the branch related to the issue you are working on.
	Stick to one branch per issue!!!

3. Working on the branch
	- Once located in the branch of your issue, work normally in Stata, R, Python, whatever it is you need to work on for the issue at hand. All this work will be local work, i.e. it will only be stored in the computer you are working on.

4. Commit changes
	- Add the files you want to upload to the remote repository by typing `git add filename`
	- **Make sure to not add files that do not belong in the remote repository**
	- Type `git status` to see which files have been added and which ones have not
	- Once you add all the files that you want to upload, commit them by typing `git commit -m '#n Informative message about what you have done'` where n is the issue number you worked on and make sure you add a # before it, as it will create a link to the file in the remote repository
	- Push your changes by typing: `git push origin nameofbranch`
		- This 'sends' the files you worked on to the remote repository, within the branch you are working on

5. Merging the branch to main
	- Go to the remote repository
	- Click on branches -> New pull request
		- This creates a new issue to pull all the material from the working branch and prepare it to merge it to the main branch.
		- Note this will add 1 to the issue counter (for whenever you want to create a new issue, keep this in mind)
		- Give a right title, check everything is OK and assign one of the PI's as a reviewer.
		**REMEMBER:**
			- The assignee will write a description of what was done in the issue and write the paths to the relevant codes and outputs.
			- The assignee is responsible for closing the issue once the issue has been declared "Accomplished" or "Not Accomplished" by all collaborators. 
		
		- Once the reviewer checks and approves the changes made in the branch you can proceed to merge the branch using `squash and merge`
		- Delete the **remote branch** once the changes are properly merged to `main`
		- Update the **local repository** with the changes from the remote by typing: `git fetch --all --prune`
		- Move back to the main branch by typing `git checkout main`
		- Pull all the changes made by either you or others by typing `git pull origin main`
		- Delete the local branch by typing `git branch -d nameofbranch`
			- If the previous command does not work you can force delete a branch by typing `git branch -D nameofbranch` ; be careful when using this since you could end up losing all your work
		- Check the local repository status by typing `git status` ; confirm you are in the main branch and that there are no other merge conflicts or uncommited changes. Also check the branch you were working on is not appearing now.