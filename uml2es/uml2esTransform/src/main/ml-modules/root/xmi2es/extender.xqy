(:
This module builds an "Extended" ES model, which consists of:
- Descriptor (JSON)
- Semantic triples describing additional aspects of the model, which are NOT captured in the descriptor. 
:)

xquery version "1.0-ml";

module namespace xes = "http://marklogic.com/xmi2es/extender"; 

import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";
import module namespace pt = "http://marklogic.com/xmi2es/problemTracker" at "/xmi2es/problemTracker.xqy";

declare variable $DEFAULT-NAMESPACE := "http://example.org/Example-1.0.0";
declare variable $DEFAULT-MODEL := "zzz";
declare variable $DEFAULT-VERSION := "0.0.1";

declare variable $IRI-PREFIX := "http://marklogic.com/xmi2es/xes#";

declare variable $PRED-REMINDER := sem:iri($IRI-PREFIX || "reminder");

declare variable $PRED-COLLECTIONS := sem:iri($IRI-PREFIX || "collections");
declare variable $PRED-PERM := sem:iri($IRI-PREFIX || "perm");
declare variable $PRED-CAPABILITY := sem:iri($IRI-PREFIX || "capability");
declare variable $PRED-ROLE := sem:iri($IRI-PREFIX || "role");
declare variable $PRED-QUALITY := sem:iri($IRI-PREFIX || "quality");
declare variable $PRED-METADATA := sem:iri($IRI-PREFIX || "metadata");
declare variable $PRED-KEY := sem:iri($IRI-PREFIX || "key");
declare variable $PRED-VALUE := sem:iri($IRI-PREFIX || "value");

declare variable $PRED-EXCLUDES := sem:iri($IRI-PREFIX || "excludes");
declare variable $PRED-RELATIONSHIP := sem:iri($IRI-PREFIX || "relationship");
declare variable $PRED-TYPE-IS-REFERENCE := sem:iri($IRI-PREFIX || "typeIsReference");
declare variable $PRED-TYPE-REFERENCE := sem:iri($IRI-PREFIX || "reference");
declare variable $PRED-ASSOCIATION-CLASS := sem:iri($IRI-PREFIX || "associationClass");
declare variable $PRED-IS-ASSOCIATION-CLASS := sem:iri($IRI-PREFIX || "isAssociationClass");
declare variable $PRED-IS-FK := sem:iri($IRI-PREFIX || "isFK");
declare variable $PRED-HAS-ASSOC-CLASS-END := sem:iri($IRI-PREFIX || "hasAssociationClassEnd");
declare variable $PRED-ASSOC-CLASS-END-ATTRIB := sem:iri($IRI-PREFIX || "associationClassEndAttribute");
declare variable $PRED-ASSOC-CLASS-END-CLASS := sem:iri($IRI-PREFIX || "associationClassEndClass");
declare variable $PRED-ASSOC-CLASS-END-FK := sem:iri($IRI-PREFIX || "associationClassEndFK");

declare variable $PRED-IS-BIZ-KEY := sem:iri($IRI-PREFIX || "isBizKey");
declare variable $PRED-IS-URI := sem:iri($IRI-PREFIX || "isURI");
declare variable $PRED-CALCULATION := sem:iri($IRI-PREFIX || "calculation");
declare variable $PRED-HEADER := sem:iri($IRI-PREFIX || "header");
declare variable $PRED-BASE-CLASS := sem:iri($IRI-PREFIX || "baseClass");

declare variable $PRED-IS-SEM-LABEL := sem:iri($IRI-PREFIX || "isSemLabel");
declare variable $PRED-SEM-PREFIXES := sem:iri($IRI-PREFIX || "semPrefixes");
declare variable $PRED-SEM-PREFIX := sem:iri($IRI-PREFIX || "semPrefix");
declare variable $PRED-SEM-REFERENCE := sem:iri($IRI-PREFIX || "semReference");
declare variable $PRED-IS-SEM-IRI := sem:iri($IRI-PREFIX || "isSemIRI");
declare variable $PRED-SEM-TYPE:= sem:iri($IRI-PREFIX || "semType");
declare variable $PRED-SEM-FACT := sem:iri($IRI-PREFIX || "semFact");
declare variable $PRED-SEM-S:= sem:iri($IRI-PREFIX || "semS");
declare variable $PRED-SEM-P := sem:iri($IRI-PREFIX || "semP");
declare variable $PRED-SEM-O := sem:iri($IRI-PREFIX || "semO");
declare variable $PRED-SEM-PREDICATE := sem:iri($IRI-PREFIX || "semPredicate");
declare variable $PRED-SEM-QUAL := sem:iri($IRI-PREFIX || "semPredicateQualifiedObject");

declare variable $LIB-SJS := "lib.sjs";
declare variable $LIB-XQY := "lib.xqy";

declare variable $NEWLINE := "&#10;";
declare variable $INDENT := "  ";

declare variable $LIB-PREFIX := "umles";

(:
PUBLIC Interface
:)

declare function xes:init($problems, $param as xs:string?) as map:map {

	map:new((
		map:entry("params", xes:getParams($param)),
		map:entry("descriptor", json:object()),
		map:entry("problems", $problems),
		map:entry("triples", json:array())
	))
};

declare function xes:generateCode($xes as map:map) as map:map {

	let $codeMap := map:new((
		map:entry($LIB-XQY, ""),
		map:entry($LIB-SJS, "")
	))

	let $_ := (
		xes:generateModuleHeader($xes, $codeMap),
		xes:generateWriter($xes, $codeMap),
		xes:generateHeaders($xes, $codeMap), 
		xes:generateTriples($xes, $codeMap),
		xes:generateContent($xes, $codeMap),	
		xes:generateModuleTrailer($xes, $codeMap))
	return $codeMap
};

declare function xes:getDescriptor($xes as map:map) as json:object {
	map:get($xes, "descriptor")
};

declare function xes:setPrefixes($xes as map:map, $modelIRI as sem:iri, $prefixes as map:map) as empty-sequence() {
	let $fullPrefixes := map:new((sem:prefixes(), $prefixes))
	let $_ := map:put($xes, "prefixes", $fullPrefixes)
	let $_ := map:put($xes, "rdfBuilder", sem:rdf-builder($fullPrefixes))
	for $p in map:keys($prefixes) return
	    xes:addQualifiedFact($xes, $modelIRI, $PRED-SEM-PREFIXES, map:new((
	   		map:entry($PRED-SEM-PREFIX, $p),
	    	map:entry($PRED-SEM-REFERENCE,map:get($prefixes, $p)))))
};

(: Take fully-qualified or curie IRI and convert to sem:iri :)
declare function xes:resolveIRI($xes as map:map, $vals as xs:string*, 
	$subjectOfProblem as sem:iri, $contextOfProblem) as sem:iri* {

	for $val in $vals return
		try {
		  sem:curie-expand($val, map:get($xes, "prefixes"))
		}
		catch($e) {
		  sem:iri($val)
		}
};

(: Take string that is fully-qualified or curie IRI and or string literal convert to either sem:iri or string literal quotes removed :)
declare function xes:resolveIString($xes as map:map, $vals as xs:string*,
	$subjectOfProblem as sem:iri, $contextOfProblem) as xs:anyAtomicType* {

	for $val in $vals return
		if (fn:starts-with($val, '"') and fn:ends-with($val, '"')) then fn:substring($val, 2, string-length($val) - 2)
		else xes:resolveIRI($xes, $val, $subjectOfProblem, $contextOfProblem)
};

(:
Add a fact to the extended model.
:)
declare function xes:addFact($xes as map:map,
	$subjectIRI as sem:iri, $predicateIRI as sem:iri, 
	$objects as xs:anyAtomicType*) as empty-sequence() {

	let $triples := map:get($xes, "triples")
	let $problems := map:get($xes,  "problems")
	return 
		if (not($subjectIRI)) then
			pt:addProblem($problems, $subjectIRI, (), $pt:ILLEGAL-XES-TRIPLE, "no subject") 
		else if (not($predicateIRI)) then
			pt:addProblem($problems, $subjectIRI, (), $pt:ILLEGAL-XES-TRIPLE, "no predicate") 
		else
			if (xdmp:type($objects) eq "array") then
				let $list := sem:bnode()
				let $_ := json:array-push($triples, map:get($xes, "rdfBuilder")($subjectIRI, $predicateIRI, $list))
				let $json-values := json:array-values($objects)
				for $object at $pos in $json-values return
					(
						json:array-push($triples, map:get($xes, "rdfBuilder")($list, "rdf:first", $object)),
						if ($pos lt count($json-values)) then 
							let $newList := sem:bnode()
							let $_ := json:array-push($triples, map:get($xes, "rdfBuilder")($list, "rdf:rest", $newList))
							let $list := xdmp:set($list, $newList)
							return ()
						else 
							json:array-push($triples, map:get($xes, "rdfBuilder")($list, "rdf:rest", sem:curie-expand("rdf:nil")))

					)
			else 
				for $object in $objects return
					json:array-push($triples, map:get($xes, "rdfBuilder")($subjectIRI, $predicateIRI, $object))
};

(:
Add qualified fact to the extended model.
:)
declare function xes:addQualifiedFact($xes as map:map,
	$subjectIRI as sem:iri, $predicateIRI as sem:iri, $qualifiedMap as map:map) 
	as empty-sequence() {

	let $qobj := sem:bnode()
	let $_ := xes:addFact($xes, $subjectIRI, $predicateIRI, $qobj)
	for $pred in map:keys($qualifiedMap) return 
		xes:addFact($xes, $qobj, sem:iri($pred), map:get($qualifiedMap, $pred))
};

(:
Parse and validate extender params. Return map entry for them. Params:
lax: true/false
:)
declare function xes:getParams($param as xs:string?) as map:map {
  let $nparam := fn:normalize-space($param)
  let $map := map:new((
    map:entry("lax", false())
  ))

  return
    if (string-length($nparam) eq 0 or $nparam eq "dummy") then $map
    else 
      let $json := xdmp:from-json-string($param)
      let $_ := for $key in map:keys($json) return
        let $val := map:get($json, $key)
        return
          if ($key eq "lax") then 
            if ($val eq "true" or $val eq true()) then map:put($map, "lax", true())
            else if ($val eq "false" or $val eq false()) then map:put($map, "lax", false())
            else fn:error(xs:QName("ERROR"), "illegal", ($key, $val))
          else fn:error(xs:QName("ERROR"), "Illegal", ($key))
      return $map
};

declare function xes:resolveBaseURI($xes, $baseURI as xs:string?) as xs:string {
	let $problems := map:get($xes, "problems")
	return 
		if (xes:emptyString($baseURI)) then 
			let $_ := pt:addProblem($problems, (), (), $pt:MODEL-BASE-URI-NOT-FOUND, ())
			return $DEFAULT-NAMESPACE
		else $baseURI
};

declare function xes:resolveVersion($xes, $version as xs:string?) as xs:string {
	let $problems := map:get($xes, "problems")
	return 
		if (xes:emptyString($version)) then 
			let $_ := pt:addProblem($problems, (), (), $pt:MODEL-VERSION-NOT-FOUND, ())
			return $DEFAULT-VERSION
		else $version
};

declare function xes:modelIRI($xes, $modelName as xs:string, $baseURI as xs:string?, $version as xs:string?) as sem:iri {
    sem:iri(concat($baseURI, "/", $modelName, "-", $version))
};

declare function xes:classIRI($xes, $modelIRI as xs:string, $className as xs:string) as sem:iri {
	sem:iri(concat($modelIRI, "/", $className))
};

declare function xes:attribIRI($xes, $classIRI as xs:string, $attribName as xs:string) as sem:iri {
	sem:iri(concat($classIRI, "/", $attribName))
};

(:
Return a turtle serialization of the XES triples. Also return a reasonably useful comment summarizing the extensions.
The comment can be pasted into your conversion module to help guide you.
:)
declare function xes:generateModelExtension($xes as map:map) as xs:string* {
	let $triples := json:array-values(map:get($xes, "triples"))
	return
		if (count($triples) eq 0) then ()
		else
			let $turtle := sem:rdf-serialize($triples, "turtle")
			let $comment := concat(
				"Your model has the following extended facts. These facts are also saved as triples in your content DB:",
				$turtle)
			return ($turtle, $comment)
};

(:
Set the one and only model 
:)
declare function xes:transform($xes as map:map, $profileForm as node()) as empty-sequence() {
	let $problems := map:get($xes, "problems")
	let $descriptor := map:get($xes, "descriptor")

	(: start with the model :)	
	let $_ := transformModel($xes, $profileForm)

	(: now the classes :)
	let $allClasses := $profileForm//Class/@name
	let $duplicateClasses := $allClasses[index-of($allClasses, .)[2]]
	let $_ := 
		if (count($duplicateClasses) gt 0) then 
			pt:addProblem($problems, (), (), $pt:MODEL-DUPLICATE-CLASSES, string-join($duplicateClasses, ","))
		else ()
	let $_ := for $class in $profileForm/classes/Class return 
		xes:transformClass($xes, $profileForm, $class)
	return ()
};

(:
Private Interface
:)

declare function xes:transformModel($xes as map:map, $profileForm as node()) as empty-sequence() {
	let $problems := map:get($xes, "problems")
	let $descriptor := map:get($xes, "descriptor")

    let $modelJson := json:object()
    let $classesJson := json:object()
    let $_ := map:put($descriptor, "info", $modelJson)
	return (
		map:put($xes, "ns", string($profileForm/modelIRI)),
		map:put($modelJson, "title", string($profileForm/name)),
    	map:put($modelJson, "version", string($profileForm/version)), 
    	map:put($modelJson, "baseUri", string($profileForm/baseURI)), 
    	map:put($modelJson, "description", string($profileForm/description)),
    	map:put($descriptor, "definitions", $classesJson))
};

declare function xes:transformClass($xes as map:map, $profileForm as node(),  
	$class as node()) as empty-sequence() {

	let $problems := map:get($xes, "problems")
	let $classesJson := map:get(map:get($xes, "descriptor"), "definitions")
	let $classIRI := $class/IRI

let $_ := xdmp:log("CLASS " || $classIRI)

	(: Gather the info about the class :)
	let $attribsJson := json:object()
	let $classJson := json:object()
	let $allAttribs := $class/attributes/Attribute
	let $includes := $allAttribs[exclude/text() eq false()]
	let $pks := $includes[PK/text() eq true()]/name/text()
	let $requireds := $includes[required/text() eq true()]/name/text()
	let $paths := $includes[pathRangeIndex/text() eq true()]/name/text()
	let $elements :=$includes[elementRangeIndex/text() eq true()]/name/text()
	let $lexicons := $includes[wordLexicon/text() eq true()]/name/text()
	let $piis := $includes[pii/text() eq true()]/name/text()

	(: Build the ES descriptor for the class :)
	return
		if ($class/exclude/text() eq true()) then ()
		else (
			map:put($classesJson, string($class/name), $classJson),
			map:put($classJson, "properties", $attribsJson),
			map:put($classJson, "description", string($class/description)),	
			if (count($requireds) gt 0) then map:put($classJson, "required", json:to-array($requireds)) else (),
			if (count($piis) gt 0) then map:put($classJson, "pii", json:to-array($piis)) else (),
			if (count($pks) gt 0) then map:put($classJson, "primaryKey", $pks) else (),
			if (count($class/xmlNamespace/@prefix)) then (
				map:put($classJson, "namespace", $class/xmlNamespace/@url),
				map:put($classJson, "namespacePrefix", $class/xmlNamespace/@prefix)						
				)
			else (),
			if (count($paths) gt 0) then map:put($classJson, "pathRangeIndex", json:to-array($paths)) else (),
			if (count($elements) gt 0) then map:put($classJson, "elementRangeIndex", json:to-array($elements)) else (),
			if (count($lexicons) gt 0) then map:put($classJson, "wordLexicon", json:to-array($lexicons)) else (),
			for $attrib in $allAttribs return 
				xes:transformAttribute($xes, $profileForm, $class, $attrib, $attribsJson)
		)
};

declare function xes:transformAttribute($xes as map:map, $profileForm as node(), 
	$class as node(), $attrib as node(), $attribsJson as json:object) as empty-sequence() {

	let $problems := map:get($xes, "problems")
	let $attribIRI := $attrib/IRI
let $_ := xdmp:log("ATTRIB " || $attribIRI)
	let $attribJson := json:object()
	let $exclude := $attrib/exclude/text() eq true()
	let $FK := $attrib/FK/text() eq true()
	let $array := $attrib/array/text() eq true()
	let $required := $attrib/required/text() eq true()
	let $PK := $attrib/PK/text() eq true()
	let $collation := $attrib/esProperty/@collation

	(: OK, let's figure out the type... :)
	let $resolveTypeResult := xes:resolveType($xes, $profileForm, $class, $attrib)
	let $type := $resolveTypeResult[1]
	let $typeKey := $resolveTypeResult[2]
let $_ := xdmp:log("*" || $type || "*" || $typeKey || "*")
	
	(: facts and problems :)
	let $_ := (
		if (string-length($collation) gt 0 and $type ne "string") then
			pt:addProblem($problems, $attribIRI, (), $pt:ATTRIB-COLLATION-NONSTRING, "") 
		else (),
		if ($PK eq true() and ($required eq false() or $array eq true())) then
			pt:addProblem($problems, $attribIRI, (), $pt:ATTRIB-CARDINALITY-ONE, "PK") 
		else ()
	)

	return
		if ($exclude eq true()) then ()
		else (
			map:put($attribsJson, $attrib/name/text(), $attribJson),
			if ($array eq true()) then 
				let $itemsJson := json:object()
				return (
					map:put($itemsJson, $typeKey, $type),
					if (string-length($collation) gt 0) then map:put($itemsJson, "collation", $collation) else (),
					map:put($attribJson, "datatype", "array"),
					map:put($attribJson, "items", $itemsJson)
				)
			else (
				map:put($attribJson, $typeKey, $type),
				if (string-length($collation) gt 0) then map:put($attribJson, "collation", $collation) else ()
			),
			map:put($attribJson, "description", string($attrib/description))
		)
};

(:
Determine the ES model descriptor type of the attribute. 
:)
declare function xes:resolveType($xes as map:map, $profileForm as node(), 
	$class as node(), $attrib as node()) as xs:string+ {

	let $problems := map:get($xes,  "problems")

	let $attribIRI := $attrib/IRI
	let $type := string($attrib/type)
	return 
		if (string-length($attrib/esProperty/@mlType) gt 0) then ($attrib/esProperty/@mlType, "datatype")
		else if (string-length($attrib/esProperty/@externalRef) gt 0) then ($attrib/esProperty/@externalRef, "$ref")
		else if ($attrib/typeIsReference/text() eq true()) then
			if (string-length(string($attrib/associationClass)) gt 0) then (concat("#/definitions/", string($attrib/associationClass)), "$ref")
			else if ($attrib/FK/text() eq true()) then
				let $refClass :=  $profileForm/classes/Class[name eq string($attrib/type)]
				let $refPKAttrib := $refClass/attributes/Attribute[PK/text() eq true()]
				return 
					if (count($refPKAttrib) ne 1) then 
						let $_ := pt:addProblem($problems, $attribIRI, (), $pt:ATTRIB-BROKEN-FK, "unable to find PK of ref")
						return (concat("broken FK: ", $type), "datatype")
					else
						let $refType := xes:resolveType($xes, $profileForm, $refClass, $refPKAttrib)
						return
							if ($refType[2] eq "$ref") then 
								let $_ := pt:addProblem($problems, $attribIRI, (), $pt:ATTRIB-BROKEN-FK, "PK of ref must be primitive")
								return (concat("broken FK: ", $type), "datatype")
							else
								$refType
			else (concat("#/definitions/", $type), "$ref")
		else if (xes:emptyString($type) and map:get(map:get($xes, "params"), "lax") eq true()) then ("string", "datatype")
		else 
			if (ends-with($type, "#String")) then ("string", "datatype")
			else if (ends-with($type, "#Boolean")) then ("boolean", "datatype")
			else if (ends-with($type, "#Real")) then ("float", "datatype")
			else if (ends-with($type, "#Integer")) then ("int", "datatype")
			else (string($type), "datatype") (: whatever it is, use it. problem get rejected by ES val :)
};

declare function xes:generateModuleHeader($xes as map:map, $codeMap as map:map) as empty-sequence() {
	let $descriptor := map:get($xes, "descriptor")
	let $ns := 	map:get($xes, "ns")
	let $_ := map:put($codeMap, $LIB-XQY, concat('xquery version "1.0-ml";', $NEWLINE, 
		'module namespace ', $NS-PREFIX, ' = "', $ns, '"', $NEWLINE, $NEWLINE))
	let $_ := map:put($codeMap, $LIB-SJS, json:array())
	return ()
};

declare function xes:generateModuleTrailer($xes as map:map, $codeMap as map:map) as empty-sequence() {
	let $descriptor := map:get($xes, "descriptor")
	let $ns := 	map:get($xes, "ns")
	let $functions := if (map:contains($xes, $LIB-SJS)) then json:array-values(map:get($xes, $LIB-SJS)) else ()
	let $_ := map:put($codeMap, $LIB-SJS, concat($NEWLINE, $NEWLINE, 'module.exports = {', $NEWLINE, 
		for $f at $pos in $functions return 
			concat($NEWLINE, $INDENT, $f, ":", $f, if ($pos lt count($functions)) then "," else ""),
		$NEWLINE, '};', $NEWLINE))
	return ()
};

declare function xes:generateHeaders($xes as map:map, $codeMap as map:map) as empty-sequence() {
	let $descriptor := map:get($xes, "descriptor")
	let $sjs := map:get($codeMap, $LIB-SJS)
	let $xqy := map:get($codeMap, $LIB-XQY)

	let $sems := <triples>{json:array-values(map:get($xes, "triples"))}</triples>
	let $semHeader := $sems/sem:triple[sem:predicate eq string($PRED-HEADER)]
	let $headerClasses := fn:distinct-values(for $t in $semHeader/sem:subject/text() return fn:tokenize($t, "/")[last()-1])
	for $className in $headerClasses
		let $sjsFunction := concat("setHeaders", $className)
		let $_ := map:put($xes, $LIB-SJS, json:array-push(map:get($xes, $LIB-SJS), $sjsFunction))
		let $sjs := concat($sjs, 'function ', $sjsFunction, '(id, content, options, lang) {', $NEWLINE)
		let $xqy := concat($xqy, 'declare function ', $LIB-PREFIX, ':setHeaders', string($class/name), 
			'($id as xs:string, $content as item()?, $options as map:map, $lang as xs:string) as node()* {', $NEWLINE)

		(: TODO - If this class has an attribute that refers to another class, bring in that class's headers too :)

		let $jBody := ""
		let $xxBody := ""
		let $xjBody := ""

		let $headersInClass := $semHeader[contains(sem:subject/text(), $className)]
		let $_ := for $triple at $pos in $headersInClass return
			let $attribIRI := $triple/sem:subject/text()
			let $attribName := fn:tokenize($attribIRI, "/")[last()]
			let $field := xes:resolveXString(string($triple/sem:object))
			let $val := if (exists($sems/sem:triple[sem:object/text() eq $attribIRI and 
				sem:predicate/text() eq string($PRED-EXCLUDES)])) then
				( concat('options[', $attribName, ']'), concat('map:get($options, "', $attribName, '")') )
				else ( concat('content[', $attribName, ']') , concat('$content/', $attribName) )

			let $jBody := concat($jBody, $NEWLINE, $INDENT, $INDENT, 'ret[', $field, '] = ', $val[1], ';')
			let $xxBody := concat($jBody, $NEWLINE, $INDENT, $INDENT, '<', $attribName, '>{', $val[2], '}</', $attribName, '>')
			let $xjBody := concat($jBody, $NEWLINE, $INDENT, $INDENT, '"', $attribName, '" : ', $val[2], 
				if ($pos lt count($headersInClass)) then " , " else "")
			return ()

		let $sjs := concat($sjs, $NEWLINE, $INDENT, "var ret = {")
		let $sjs := concat($sjs, $NEWLINE, $INDENT, $INDENT, 'lastHarmonizeTS: new Date(),')
		let $sjs := concat($sjs, $NEWLINE, $INDENT, $INDENT, 'entityType: "', $className, '",')
		let $sjs := concat($sjs, $NEWLINE, $INDENT, $INDENT, 'sourceDocument: id')
		let $sjs := concat($sjs, $NEWLINE, $INDENT, "};")
		let $sjs := concat($sjs, $jBody)
		let $sjs := concat($sjs, $NEWLINE, $INDENT, "return ret;")
		let $sjs := concat($sjs, $NEWLINE, "}")

		let $xqy := concat($xqy, $NEWLINE, $INDENT, 'if ($lang eq "xml") then <Header>')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, $INDENT, '<lastHarmonizeTS>{fn:current-dateTime()}</lastHarmonizeTS>')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, $INDENT, '<entityType>', $className, '</entityType>')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, $INDENT, '<sourceDocument>{$id}</sourceDocument>')
		let $xqy := concat($xqy, $xxBody)
		let $xqy := concat($xqy, $NEWLINE, $INDENT, "</Header>")
		let $xqy := concat($xqy, $NEWLINE, $INDENT, 'else if ($lang eq "json") then object-node { ')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, $INDENT, '"lastHarmonizeTS" : fn:current-dateTime() ,')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, $INDENT, '"entityType" : "', $className, '" ,')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, $INDENT, '"sourceDocument": $id ,')
		let $xqy := concat($xqy, $xjBody)
		let $xqy := concat($xqy, $NEWLINE, $INDENT, "}")
		let $xqy := concat($xqy, $NEWLINE, $INDENT, 'else fn:error(xq.QName("ERROR"), "illegal lang *" || $lang || "*")')
		let $xqy := concat($xqy, $NEWLINE, '};')

		return (map:put($codeMap, $LIB-SJS, $sjs), map:put($codeMap, $LIB-XQY, $xqy))
};

declare function xes:generateWriter($xes as map:map, $codeMap as map:map) as empty-sequence() {
	let $descriptor := map:get($xes, "descriptor")
	let $sjs := map:get($codeMap, $LIB-SJS)
	let $xqy := map:get($codeMap, $LIB-XQY)

	let $sems := <triples>{json:array-values(map:get($xes, "triples"))}</triples>
	let $semXDoc := $sems/sem:triple[
		sem:predicate eq string($PRED-COLLECTIONS) or
		sem:predicate eq string($PRED-PERM) or
		sem:predicate eq string($PRED-QUALITY) or
		sem:predicate eq string($PRED-METADATA)]
	let $semXURI :=$sems/sem:triple[sem:predicate eq string($PRED-IS-URI)]
	let $writerClasses := fn:distinct-values(
		for $t in $semXDoc/sem:subject/text() return fn:tokenize($t, "/")[last()],
		for $t in $semXURI/sem:subject/text() return fn:tokenize($t, "/")[last() - 1])
	for $className in $writerClasses
		let $sjsFunction := concat("runWriter", $className)
		let $_ := map:put($xes, $LIB-SJS, json:array-push(map:get($xes, $LIB-SJS), $sjsFunction))
		let $sjs := concat($sjs, 'function ', $sjsFunction, '(id, envelope, options) {', $NEWLINE)
		let $xqy := concat($xqy, 'declare function ', $LIB-PREFIX, ':runWriter', string($class/name), 
			'($id as xs:string, $envelope as item(), $options as map:map) as empty-sequence() {', $NEWLINE)
		let $xuriVal :=
			if (count($semXURI) ne 1) then ("id", "$id")
			else 
				let $attribName := fn:tokenize($semXURI/sem:subject/text(), "/")[last()]
				return 
					if (exists($sems/sem:triple[sem:object/text() eq $semXURI/sem:subject and 
						sem:predicate/text() eq string($PRED-EXCLUDES)])) then 
						(concat('options[', $attribName, ']'), concat('map:get($options, "', $attribName, '")'))
					else (concat('content[', $attribName, ']'), concat('content/', $attribName))

		let $classDocs := $sems/sem:triple[
			sem:subject/text() eq $className and 
			(sem:predicate eq string($PRED-COLLECTIONS) or
			sem:predicate eq string($PRED-PERM) or
			sem:predicate eq string($PRED-QUALITY) or
			sem:predicate eq string($PRED-METADATA))]

		let $sjs := concat($sjs, $NEWLINE, $INDENT, 'var uri = ', $xuriVal[1])
		let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $uri := ', $xuriVal[2])

		let $sjs := concat($sjs, $NEWLINE, $INDENT, 'var dioptions = {};')
		let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $dioptions := map:map()')

		let $colls := $classDocs/sem:triple[sem:predicate eq string($PRED-COLLECTIONS)]
		let $_ := 
			if (count($colls) gt 0) then
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'var collections = [];')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $collections := json:array()')
				let $_ := for $coll in $colls/sem:triple/sem:object/text()
					let $field := xes:resolveXString($coll)
					let $val := if (exists($sems/sem:triple[sem:object/text() eq $attribIRI and 
						sem:predicate/text() eq string($PRED-EXCLUDES)])) then
						( concat('options[', $attribName, ']'), concat('map:get($options, "', $attribName, '")') )
						else ( concat('content[', $attribName, ']') , concat('$content/', $attribName) )
					let $sjs := concat($sjs, $NEWLINE, $INDENT, 'collections.push(', $val[1], '];')
					let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := json:array-push($collections, ', $val[2], ')')
					return ()
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'dioptions.collections = collections;')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($dioptions, "collections", json:array-values($collections))')
				return ()
			else
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'dioptions.collections = options.entity;')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($dioptions, "collections", map:get($options, "entity"))')
				return()

		let $perms := $classDocs/sem:triple[sem:predicate eq string($PRED-PERM)]
		let $_ := 
			if (count($perms) gt 0) then
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'var perms = [];')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $perms := json:array()')
				let $_ := for $perm in $perms/sem:triple/sem:object/text()
					let $role := $sems/sem:triple[sem:subject/text() eq $perm and sem:predicate/text() eq string($PRED-ROLE)]/sem:object/text()
					let $capability := $sems/sem:triple[sem:subject/text() eq $perm  and sem:predicate/text() eq string($PRED-CAPABILITY)]/sem:object/text()
					let $sjs := concat($sjs, $NEWLINE, $INDENT, 'perms.push(xdmp.permission("', $role, '","', $capability, '"));')
					let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := json:array-push($perms, xdmp:permission("', $role, '","', $capability, '"))')
					return ()
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'dioptions.permissions = perms;')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($dioptions, "permissions", json:array-values($perms))')
				return ()
			else 
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'dioptions.permissions = xdmp.defaultPermissions();')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($dioptions, "permissions", xdmp:default-permissions())')
				return ()

		let $mds := $classDocs/sem:triple[sem:predicate eq string($PRED-METADATA)]
		let $_ := 
			if (count($mds) gt 0) then
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'var mds = {};')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $mds := map:map()')
				let $_ := for $md in $perms/sem:triple/sem:object/text()
					let $k := $sems/sem:triple[sem:subject/text() eq $mds and sem:predicate/text() eq string($PRED-KEY)]/sem:object/text()
					let $v := $sems/sem:triple[sem:subject/text() eq $mds  and sem:predicate/text() eq string($PRED-VALUE)]/sem:object/text()
					let $sjs := concat($sjs, $NEWLINE, $INDENT, 'mds["', $k, '"] = "', $v, '";')
					let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($mds, "', $k, '", "', $v, '")')
					return ()
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'dioptions.metadata = mds;')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($dioptions, "metadata", $mds)')
				return ()
			else ()

		let $qual := $classDocs/sem:triple[sem:predicate eq string($PRED-QUALITY)]
		let $_ := 
			if (count($qual) eq 1) then
				let $val := $qual/sem:triple/sem:object/text()
				let $sjs := concat($sjs, $NEWLINE, $INDENT, 'dioptions.quality = ', $val, ';')
				let $xqy := concat($xqy, $NEWLINE, $INDENT, 'let $_ := map:put($dioptions, "quality", ', $val, ')')
				return ()
			else ()

		let $sjs := concat($sjs, $NEWLINE, $INDENT, 'xdmp.documentInsert(uri, envelope, dioptions);')
		let $xqy := concat($sjs, $NEWLINE, $INDENT, 'return xdmp:document-insert($uri, $envelope, $dioptions)')
		let $sjs := concat($sjs, $NEWLINE, '}')
		let $xqy := concat($sjs, $NEWLINE, '};')
		return (map:put($codeMap, $LIB-SJS, $sjs), map:put($codeMap, $LIB-XQY, $xqy))
};

declare function xes:generateTriples($xes as map:map, $codeMap as map:map) as empty-sequence() {
	""
};

declare function xes:generateContent($xes as map:map, $codeMap as map:map) as empty-sequence() {
	""
};

declare function xes:emptyString($s) {
	not($s) or string-length($s) eq 0
};


