@router.register 'irc/command/hello' do |cmd, ctx|
  cmd.reply("Hi there!")
end
