module MailHelper
  
  def standard_html_email_wrapper
    <<-END_HTML
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html>
      <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
      </head>
      <body leftmargin="0" marginwidth="0" topmargin="0" marginheight="0" offset="0" style="-webkit-text-size-adjust: none;margin: 0;padding: 0;background-color: #FAFAFA;width: 100%;">
        <center>
          #{yield}
        </center>
      </body>
    </html>
    END_HTML
  end
  
end