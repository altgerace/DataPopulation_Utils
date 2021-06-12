# DataPopulation_Utils


IRIS-based utility that, given a set of classes, can enable the existing %Populate utilities on these classes and generate type-relevant property POPSPEC methods.


Dummy data can then be generated on the classes using %Populate. The utility follows class dependencies, e.g. Parent relationship classes and object type properties marked Required, to populate the classes in a necessary order.


It can conversely remove the POPSPEC parameter from every property in a class and disable %Populate on the class.



## How to use:



To enable data population on a set of classes and populate each classes with *numPop* many instances, run the following: 

  `set st = ##class(DataPopulation.Utils).PopulateWithData(.classes, numPop)`




See the signature below:


  ```ObjectScript
  /// PARAMETERS:
  /// 	classes is a single package, a single class, or a node array of classes passed by reference.
  /// 		These classes will have %Populate added as a superclass and POPSPEC added as a property parameter where suited.
  /// 	numPop specifies the amount of objects that we will try to create with Populate. 
  /// 	tune controls whether Tune Table is run after all populated objects have been saved.
  /// 		If tune is not true, Tune Table is not run.
  /// 		If tune is true, Tune Table is run.
  /// 		If tune > 1, Tune Table is also run for any tables projected by persistent superclasses of each class in parameter classes.
  /// 	If verbose is true, error messages, compilation output, and population logs are displayed.
  /// 	If rollbackOnError is true, we rollback changes to classes on encountering an error. 
  ClassMethod PopulateWithData(ByRef classes = "", numPop As %Integer = 10, tune As %Integer = 0, verbose As %Boolean = 0, rollbackOnError As %Boolean = 1) As %Status
  ```




To enable data population on a set of classes without immediately generating and saving instances:

  `set st = ##class(DataPopulation.Utils).EnablePopulate(.classes)`




To disable data population on a set of classes:

  `set st = ##class(DataPopulation.Utils).DisablePopulate(.classes)`




## TODO

- [ ] Establish unit test cases.
