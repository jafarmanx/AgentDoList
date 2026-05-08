class ExportMailer < ApplicationMailer
  def completed(export)
    @export = export
    @user = export.user

    mail to: @user.identity.email_address, subject: "Your CurioArch data export is ready for download"
  end
end
