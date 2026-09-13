A. Product and experience
1. The public site should be one long scrolling page with all the sections, that's correct
2. The site content will be in spanish since the admin will add all the content in spanish, however all the code and the project will be in english
3. Yes, you will find the mockups here:
/Users/miguelangel/Documents/projects/photographer-portfolio/handoff/PC view mockup.jpeg
/Users/miguelangel/Documents/projects/photographer-portfolio/handoff/mobile view mockup.jpeg

However, the content is not fully accurate, there are some sections that we won't use, so stick to the design on the parts that apply, follow the order I shared on the context and when the mockup doesn't represents what the context indicates, the context has priority.
For styling, use tailwind, you can use materialui when you consider it can make a big difference, but when possibe don;t use it since it is too heavy

4. google ranking matters a lot, however we will stick with react, keep in mind that the budget is low if google ranking needs any sort of payment

5. About image protection, block screenshots and downloads, and right click

6. fixed in code

B. Data model details
7. Exactly, one single record
8. No, the order is fixed and won't be customizable
9. Each album needs a cover photo, but it will be one of the uploaded ones, (Good catch, we need to consider this for the relational model for portfolio), about metadata, do you consider important to keep record of this for this sit? if not, then we can bypass these fields
10. I don't need status or a readble URL for now
11. No, I don't need nothing beyond the name and the logo
12. no, nothing beyond
13. Only those fixed
14. The admin just stores a phone number

C. Contact form
15. Both, let them appear in the panel and use the rails mailer
16. don't have a domain, just a personal account 
17. name, email, project in mind, phone number.
18. Let's go with your recommendation

D. Admin and authentication
19. Let's create one initial admin account by a setup script, with a change password request after the first login. That admin can create multiple admin accounts after that, so there will be more
20. a forgot password email is required, two-factor auth isn;t required
21. it lives under the same app after the /admin prefix
22. Let's go with cookie sessions

E. Images and Cloudinary
23. I already have an account, let's hope the volume is enough to be handled with the free plan
24. Let's go with direct signed uploads, let's avoid sending files to the API
25. Yes, the admin should be able to select many photos at once when creating an album, that's correct

F. Backend and tooling
26. yes, that ruby and rails version is okay, we won't be needing redis until we find a good reason to implement it
27. let's go with your proposed values
28. Jest is firm, is one of the most solid production tools for testing
29. pnpm
30. Is playwright like a scrapper? if it is, it would be too heavy and not requiresd
31. only Postgres for now

G. Deployment and repository
32. Deferrerd, we will determine that once the development process is complete
33. Only for tests and lint for now, the CI pipeline for deployment is deferrerd
34. The repository doesn't exists yet, we need to create it and make it private. main will be the base branch, every implementation agent will create a branch and a open a PR to merge for every change they do
35. yes, keep the following conventions:
Feature: for creating new features or continue work according to the plan
fix: for a reported bug from a Quality agent or matters like that
Then the number of the commit type, for instance Feature 3 while there's another commit called fix 1
then a one line summary of the commit, like this:
Feature 1: push the first commit of the monorepo

H. Orchestration workflow
36. I won't exactly copy paste the prompts, you will write the prompt on the prompt folder, one file per prompt, and I'll personally dispatch the agent from a new session
37. Once an agent, either implementation or QA finishes and creates the output file with its output on the agent-outputs folder, I'll make verify it, discuss with you as the orchestrator if it is good to go, and then continue if everything is okay
38. ALWAYS in english


