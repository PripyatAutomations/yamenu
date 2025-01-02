- Implement need_login attribute for menus and menu items
- fix cisco-login.pl
- Implement img_on and img_off types (exclusive of img)
- Make script to validate the yaml using yq for syntax
  - Confirm it has Position attrib on softkeys and throw error instead of
    emitting broken XML
- Auth:
    * Store device name, IP when sent
    * Create a cookie, stored in database which we
      try to keep active by resending rather than
      rehashing
    - Use a safe hash to make random token for cookie
