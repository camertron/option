module EitherNamespace

  class EitherMatcher
    attr_reader :return_value

    def initialize(either)
      @either = either
      @return_value = nil
    end

    def case(either_type)
      if either_type == Left
        @return_value = yield(@either.left.get) if @either.left?
      elsif either_type == Right
        @return_value = yield(@either.right.get) if @either.right?
      else
        raise TypeError, "#{either_type} is not Left or Right."
      end
    end
  end

  class EitherType
    attr_reader :left_type, :right_type

    def initialize(left_type, right_type)
      if !left_type.is_a?(Class) || !right_type.is_a?(Class)
        raise TypeError, "must specify two Class types."
      end

      @left_type = left_type
      @right_type = right_type
    end

    class << self
      def for_classes(klass1, klass2)
        either_type_cache[[klass1, klass2]] ||= new(klass1, klass2)
      end

      private

      def either_type_cache
        @either_type_cache ||= {}
      end
    end

    def wrap
      EitherClass.new(self, yield)
    end

    def wrap_error
      error = nil
      result = nil

      begin
        result = yield
      rescue => e
        error = e
      end

      EitherClass.new(self, error ? error : result)
    end
  end

  class EitherClass
    attr_reader :either_type, :value

    def initialize(either_type, value)
      if !value.is_a?(either_type.left_type) && !value.is_a?(either_type.right_type)
        raise TypeError, "value must be either a #{either_type.left_type} or a #{either_type.right_type}. Got a #{value.class} instead."
      end

      @either_type = either_type
      @value = value
    end

    def left?
      value.is_a?(either_type.left_type)
    end

    def right?
      value.is_a?(either_type.right_type)
    end

    def left
      @left_proj ||= LeftProjection.new(self)
    end

    def right
      @right_proj ||= RightProjection.new(self)
    end

    def match
      matcher = EitherMatcher.new(self)
      yield matcher
      matcher.return_value
    end

    def type_string
      "Either[#{left_type_string}, #{right_type_string}]"
    end

    def inspect
      "#<#{type_string}:0x#{'%x' % (object_id << 1)} @value=#{value.inspect}>"
    end

    private

    def left_type_string
      if either_type.left_type == EitherClass && value.is_a?(EitherClass)
        value.type_string
      else
        either_type.left_type.to_s
      end
    end

    def right_type_string
      if either_type.right_type == EitherClass && value.is_a?(EitherClass)
        value.type_string
      else
        either_type.right_type.to_s
      end
    end
  end

  class EitherProjection
    def initialize(either)
      @either = either
    end

    def to_a
      [get]
    end

    def get
      if correct_type?
        @either.value
      else
        raise TypeError, "not a #{self.class}"
      end
    end

    def get_or_else
      yield unless correct_type?
    end

    def each(&blk)
      blk.call(get) if correct_type?
      nil
    end

    def or_nil
      correct_type? ? get : nil
    end

    def empty?
      !correct_type?
    end

    def fold(if_empty, &blk)
      if correct_type?
        blk.call(get)
      else
        if_empty.call
      end
    end

    def exists?(&blk)
      if correct_type?
        !!blk.call(get)
      else
        false
      end
    end

    def include?(value)
      correct_type? ? get == value : false
    end

    def filter(&blk)
      if correct_type?
        exists?(&blk) ? self : None
      else
        self
      end
    end

    def inside(&blk)
      blk.call(get) if correct_type?
      self
    end

    def or_else(&blk)
      if correct_type?
        self
      else
        assert_either(block.call)
      end
    end

    def flatten
      if correct_type?
        case get
          when EitherProjection then get.flatten
          else self
        end
      else
        self
      end
    end

    def error(*argv)
      if correct_type?
        self
      else
        argv.empty? ? raise : raise(*argv)
      end
    end

    def present
      correct_type?
    end

    protected

    def correct_type?
      raise NotImplementedError
    end

    def assert_either(result)
      case result
        when EitherClass then return result
        else raise TypeError, "must be an Either"
      end
    end
  end

  class LeftProjection < EitherProjection
    def map(&blk)
      result = blk.call(get)
      Either[EitherClass, @either.either_type.right_type].wrap do
        Either[result.value.class, @either.either_type.right_type].wrap do
          result.value
        end
      end
    end

    def flat_map(&blk)
      result = assert_either(blk.call(get))
      Either[result.value.class, @either.either_type.right_type].wrap do
        result.value
      end
    end

    def type_string
      @either.either_type.left_type.to_s
    end

    protected

    def correct_type?
      @either.left?
    end
  end

  class RightProjection < EitherProjection
    def map(&blk)
      result = blk.call(get)
      Either[@either.either_type.left_type, EitherClass].wrap do
        Either[@either.either_type.left_type, result.value.class].wrap do
          result.value
        end
      end
    end

    def flat_map(&blk)
      result = assert_either(blk.call(get))
      Either[@either.either_type.left_type, result.value.class].wrap do
        result.value
      end
    end

    def type_string
      @either.either_type.right_type.to_s
    end

    protected

    def correct_type?
      @either.right?
    end
  end
end

class Left
  private; def initialize; end
end

class Right
  private; def initialize; end
end

module Either
  class << self
    def [](left_type, right_type)
      EitherNamespace::EitherType.for_classes(left_type, right_type)
    end
  end
end
