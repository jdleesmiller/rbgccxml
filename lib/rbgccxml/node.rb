module RbGCCXML

  class NotQueryableException < RuntimeError; end
  class UnsupportedMatcherException < RuntimeError; end

  # A Node is part of the C++ code as dictated by GCC-XML. This class 
  # defines all of the starting points into the querying system, along 
  # with helper methods to access data from the C++ code itself.
  #
  # Any Node further down the heirarchy chain can and should define which 
  # finder methods are and are not avaiable at that level. For example, the 
  # Class node cannot search for other Namespaces within that class.
  class Node 
    attr_reader :node

    # Initialize this node according to the XML element passed in
    # Only to be used internally.
    def initialize(node)
      @node = node
    end
    protected :initialize

    # Get the C++ name of this node
    def name
      @node.attributes['name']
    end
    
    # Get the fully qualified (demangled) C++ name of this node.
    def qualified_name
      if @node.attributes["demangled"]
        # The 'demangled' attribute of the node for methods / functions is the 
        # full signature, so cut that part out.
        @node.attributes["demangled"].split(/\(/)[0]
      else
        parent ? "#{parent.qualified_name}::#{name}" : name
      end
    end

    # Is this node const qualified?
    def const?
      @node.attributes["const"] ? @node.attributes["const"] == "1" : false
    end

    # Does this node have public access?
    def public?
     @node.attributes["access"] ? @node.attributes["access"] == "public" : true
    end

    # Does this node have protected access?
    def protected?
     @node.attributes["access"] ? @node.attributes["access"] == "protected" : false
    end

    # Does this node have private access?
    def private?
     @node.attributes["access"] ? @node.attributes["access"] == "private" : false
    end

    # Forward up attribute array for easy access to the
    # underlying XML node
    def attributes
      @node.attributes
    end

    # Some C++ nodes are actually wrappers around other nodes. For example, 
    #   
    #   typedef int ThisType;
    #
    # You'll get the TypeDef node "ThisType". Use this method if you want the base type for this
    # typedef, e.g. the "int".
    def base_type
      self
    end

    # Returns the full path to the file this node is found in.
    # Returns nil if no File node is found for this node
    def file
      file_id = @node.attributes["file"]
      file_node = XMLParsing.find(:node_type => "File", :id => file_id) if file_id
      file_node ? file_node.attributes["name"] : nil
    end

    # Returns the parent node of this node. e.g. function.parent will get the class
    # the function is contained in.
    def parent
      return nil if @node.attributes["context"].nil? || @node.attributes["context"] == "_1"
      XMLParsing.find(:id => @node.attributes["context"])
    end

    # This is a unified search routine for finding nested nodes. It
    # simplifies the search routines below significantly.
    def find_nested_nodes_of_type(type, matcher = nil, &block)
      res = XMLParsing.find_nested_nodes_of_type(@node, type)

      case matcher
      when String
        res = res.find(:name => matcher)
      when Regexp
        res = res.find_all { |t| t.name =~ matcher }
      when nil
        # Do nothing, since not specifying a matcher is okay.
      else
        message = "Can't handle a match condition of type #{matcher.class}."
        raise UnsupportedMatcherException.new(message)
      end

      res = res.find_all(&block) if block

      res
    end
    private :find_nested_nodes_of_type

    # Find all namespaces. There are two ways of calling this method:
    #   #namespaces  => Get all namespaces in this scope
    #   #namespaces(name) => Shortcut for namespaces.find(:name => name)
    #
    # Returns a QueryResult unless only one node was found
    def namespaces(name = nil, &block)
      find_nested_nodes_of_type("Namespace", name, &block)
    end

    # Find all classes in this scope. 
    # See Node.namespaces
    def classes(name = nil, &block)
      find_nested_nodes_of_type("Class", name, &block)
    end

    # Find all structs in this scope. 
    # See Node.namespaces
    def structs(name = nil, &block)
      find_nested_nodes_of_type("Struct", name, &block)
    end

    # Find all functions in this scope. Functions are free non-class
    # functions. To search for class methods, use #methods.
    #
    # See Node.namespaces
    def functions(name = nil, &block)
      find_nested_nodes_of_type("Function", name, &block)
    end

    # Find all enumerations in this scope. 
    # See Node.namespaces
    def enumerations(name = nil, &block)
      find_nested_nodes_of_type("Enumeration", name, &block)
    end
    
    # Find all variables in this scope
    def variables(name = nil, &block)
      find_nested_nodes_of_type("Variable", name, &block)
    end

    # Find all typedefs in this scope
    def typedefs(name = nil, &block)
      find_nested_nodes_of_type("Typedef", name, &block)
    end

    # Print out the full C++ valid code for this node.
    # By default, it just prints out the qualified name of this node.
    # See various type classes to see how this method is really used
    def to_cpp(qualified = true)
      qualified ? self.qualified_name : self.name
    end
  end

end
