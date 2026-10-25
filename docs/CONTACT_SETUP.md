# Contact form setup

1. Create a free account at https://formspree.io
2. Create a new form and verify the inbox where you want messages
3. Copy your form endpoint, e.g. `https://formspree.io/f/xyzabcde`
4. Edit `docs/contact.html` and replace `FORMSPREE_ENDPOINT` in the form `action` with that id/path
5. Enable **GitHub Pages** on this repository (Settings → Pages → Deploy from branch → `/ docs` or root)
6. Open the contact page URL and send a test message

Your personal email stays private inside Formspree; only the form URL is public.
