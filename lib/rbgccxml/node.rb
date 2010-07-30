module RbGCCXML

  class NotQueryableException < RuntimeError; end
  class UnsupportedMatcherException < RuntimeError; end

  # A Node is part of the C++ code as dictated by GCC-XML. This class 
  # defines all of the starting points into the querying system, along 
  # with helper methods to access data from the C++ code itself.
  #
  # Any Node further down the heirarchy chain can and should define which 
  # finder methods are and are not avaiable at that level. For example, the 
  # Class node cannot search for other Namespaces within that class, and any
  # attempt to will throw a NotQueryableException.
  class Node 

    # GCC_XML id of this node
    attr_accessor :id

    # The C++ scoping parent of this node
    attr_accessor :parent

    # Any children this node has
    attr_accessor :children

    # The base name of this node
    attr_accessor :name

    # Hash of all the attributes
    attr_accessor :attributes

    # Initialize this node according to the attributes passed in
    # Only to be used internally. Use query methods on the object
    # returned by RbGCCXML::parse
    def initialize(attributes)
      @id = attributes.delete("id")
      @name = attributes.delete("name")
      @demangled = attributes.delete("demangled")

      @attributes = attributes
    end
    
    # Get the fully qualified (demangled) C++ name of this node.
    def qualified_name
      if @demangled
        # The 'demangled' attribute of the node for methods / functions is the 
        # full signature, so cut that part out.
        @demangled.split(/\(/)[0]
      else
        @parent ? "#{@parent.qualified_name}::#{@name}" : @name
      end
    end
    once :qualified_name

    # Is this node const qualified?
    def const?
      @attributes["const"] ? @attributes["const"] == "1" : false
    end

    # Does this node have public access?
    def public?
     @attributes["access"] ? @attributes["access"] == "public" : true
    end

    # Does this node have protected access?
    def protected?
     @attributes["access"] ? @attributes["access"] == "protected" : false
    end

    # Does this node have private access?
    def private?
     @attributes["access"] ? @attributes["access"] == "private" : false
    end

    # Access indivitual attributes directly
    def [](val)
      @attributes[val]
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
      file_id = @attributes["file"]
      file_node = NodeCache.find_by_id(file_id)
      file_node ? file_node.name : nil
    end
    once :file

    # This is a unified search routine for finding nested nodes. It
    # simplifies the search routines below significantly.
    def find_children_of_type(type, matcher = nil)
      NodeCache.find_children_of_type(self, type, matcher)
    end
    private :find_children_of_type

    # Find all namespaces. There are two ways of calling this method:
    #   #namespaces  => Get all namespaces in this scope
    #   #namespaces(name) => Shortcut for namespaces.find(:name => name)
    #
    # Returns a QueryResult unless only one node was found
    def namespaces(name = nil)
      find_children_of_type("Namespace", name)
    end

    # Find all classes in this scope. 
    #
    # See Node.namespaces
    def classes(name = nil)
      find_children_of_type("Class", name)
    end

    # Find all structs in this scope. 
    #
    # See Node.namespaces
    def structs(name = nil)
      find_children_of_type("Struct", name)
    end

    # Find all functions in this scope. 
    #
    # See Node.namespaces
    def functions(name = nil)
      find_children_of_type("Function", name)
    end

    # Find all enumerations in this scope. 
    #
    # See Node.namespaces
    def enumerations(name = nil)
      find_children_of_type("Enumeration", name)
    end
    
    # Find all variables in this scope
    #
    # See Node.namespaces
    def variables(name = nil)
      find_children_of_type("Variable", name)
    end

    # Find all typedefs in this scope
    #
    # See Node.namespaces
    def typedefs(name = nil)
      find_children_of_type("Typedef", name)
    end

    # Print out the full C++ valid code for this node.
    # By default, it will print out the fully qualified name of this node.
    # See various Type classes to see how else this method is used.
    def to_cpp(qualified = true)
      qualified ? self.qualified_name : self.name
    end
  end

end
