$:.push("./lib")
require 'pry-nav'
require 'either'

either = Either[String, Fixnum].wrap { "foo" }
puts(either.match do |matcher|
  matcher.case(Left) { "I'm a string!" }
  matcher.case(Right) { "I'm a number!" }
end)

# binding.pry
# foo.right.map { |hello| Either[Fixnum, String].wrap { 1 } }.type_string