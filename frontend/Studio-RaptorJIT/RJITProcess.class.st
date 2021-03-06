"
I represent the cold state of a RaptorJIT process that finished executing.

I provide access to logs and diagnostic data.
"
Class {
	#name : #RJITProcess,
	#superclass : #Object,
	#instVars : [
		'dwarf',
		'auditLog',
		'vmprofiles',
		'path',
		'name'
	],
	#category : #'Studio-RaptorJIT'
}

{ #category : #accessing }
RJITProcess >> auditLog [
	^ auditLog
]

{ #category : #accessing }
RJITProcess >> auditLog: aRJITAuditLog [ 
	auditLog := aRJITAuditLog
]

{ #category : #accessing }
RJITProcess >> dwarf [
	^ dwarf
]

{ #category : #accessing }
RJITProcess >> dwarf: aDWARF [ 
	dwarf := aDWARF
]

{ #category : #'instance creation' }
RJITProcess >> fromPath: aPath [
	| dwarfPath auditPath |
	path := aPath asFileReference.
auditPath := path / 'audit.log'.
	[ auditPath isFile ] assertWithDescription:
		'JIT audit log not found in ', path asString.
	auditLog := RJITAuditLog new loadFromFileNamed: auditPath pathString.
	auditLog process: self.
	"Load VMProfile data with progress monitoring."
	vmprofiles := OrderedCollection new.
	(self vmprofilePathsUnder: aPath)
		do: [ :vmprofile |
			vmprofiles add: (RJITVMProfile loadFromFileNamed: vmprofile pathString name: vmprofile basenameWithoutExtension process: self) ]
		displayingProgress: [ :x | 'Loading VMProfile: ', x base ].
	UIManager default inform: 'Loaded ', vmprofiles size asString, ' RaptorJIT profiles'.
]

{ #category : #'instance creation' }
RJITProcess >> gtHotTracesFor: aView [
	<gtView>
	| profiles |
	profiles := self traceProfiles sort: [ :a :b | a all > b all ].
	^ (profiles subjectViewTitled: 'Hot traces' translated subjectName: 'Trace' translated onView: aView) priority: 15.

]

{ #category : #accessing }
RJITProcess >> gtInspectorEventsIn: composite [
	"<gtInspectorPresentationOrder: 6>"
	composite fastList
		title: 'Events';
		display: [ self auditLog events reverse ];
		format: [ :e |
			"Catch errors."
			[ e printString ] on: Error do: [ :err | '<Decoding error: ', err printString, '>' ] ].

]

{ #category : #accessing }
RJITProcess >> gtInspectorFilesIn: composite [
	"<gtInspectorPresentationOrder: 9>"
	path gtInspectorItemsIn: composite.

]

{ #category : #accessing }
RJITProcess >> gtInspectorTraceListIn: composite [
	"<gtInspectorPresentationOrder: 1>"
	composite fastTable
		title: 'Trace List';
		display: [ self auditLog traces ];
		column: 'Nr' evaluated: [ :tr | tr traceno asString ] width: 50 tags: nil sortedBy: #traceno descending;
		column: 'Link' evaluated: #linkname width: 80;
		column: 'Samples' evaluated: #totalSamples width: 80 tags: nil sortedBy: [ :a :b | (self totalSamplesFor: a) > (self totalSamplesFor: b) ];
		column: 'Summary' evaluated: #printString width: 800;
		installExportToCSV.

]

{ #category : #accessing }
RJITProcess >> gtInspectorTraceMapIn: composite [
	"<gtInspectorPresentationOrder: 2>"
	composite roassal2
		title: 'Trace Map';
		initializeView: [ self traceMapView ].

]

{ #category : #'instance creation' }
RJITProcess >> gtInspectorVMProfilesIn: composite [
	"<gtInspectorPresentationOrder: 5>"
	| w percent |
	w := 50. "width of numeric columns"
	^ composite tabulator
		title: 'VM Profile';
		with: [ :t |
			t row: #profiles; row: #locations; row: #traces.
			t transmit to: #profiles; andShow: [ :a |
				percent := [ :sel |
					[ :obj |
						[ ((obj perform: sel) round: 1) asString , '%' ] on: ZeroDivide do: [ '-' ] ] ].
				a fastTable
					title: 'Profiler datasets (VMProfile)';
					display: #vmprofiles;
					column: 'Profile' evaluated: #name width: 100;
					column: 'Samples' evaluated: #total width: 60
						tags: nil sortedBy: [ :x :y | x total > y total ];
					column: 'Mcode' evaluated: (percent value: #mcodePercent) width: w
						tags: nil sortedBy: [ :x :y | x mcode > y mcode ];
					column: 'VM' evaluated: (percent value: #vmPercent) width: w
						tags: nil sortedBy: [ :x :y | x vm > y vm ];
					column: 'GC' evaluated: (percent value: #gcPercent) width: w
						tags: nil sortedBy: [ :x :y | x gc > y gc.	] ].
			t transmit from: #profiles; to: #locations; andShow: [ :a |
				a fastTable
					title: 'Source code locations of root traces that are hot in the selected profile';
					display: [ :profile | profile locations select: [ :x | x samples > 0 ] ];
					sorted: [ :x :y | x samples > y samples ];
					column: 'Location' evaluated: #location width: 240;
					column: 'Samples' evaluated: #samples width: 60;
					column: 'Mcode' evaluated: (percent value: #mcodePercent) width: w;
					column: 'VM' evaluated: (percent value: #vmPercent) width: w;
					column: 'GC' evaluated: (percent value: #gcPercent) width: w;
					column: '#Root' evaluated: #numberOfRootTraces width: w;
					column: '#Side' evaluated: #numberOfSideTraces width: w. ].
			t transmit from: #locations; to: #traces; andShow: [ :a |
				a fastTreeTable
					title: 'Root traces starting at selected location (and their side-traces as children)';
					display: #profiledTraces;
					children: #children;
					sorted: [ :x :y | x samples > y samples ];
					column: 'Trace' evaluated: #traceno width: 160;
					column: 'Samples' evaluated: #samples width: 60;
					column: 'Link' evaluated: #linkname width: 60;
					column: 'Mcode' evaluated: (percent value: #mcodePercent) width: w;
					column: 'VM' evaluated: (percent value: #vmPercent) width: w;
					column: 'GC' evaluated: (percent value: #gcPercent) width: w;
					column: 'Start line' evaluated: #location width: 240;
					column: 'Stop line' evaluated: [ :x | '-' ] width: 240;
					allExpanded. ].
			t transmit toOutsidePort: #selection; from: #traces port: #selection transformed: #trace.
			].

]

{ #category : #'instance creation' }
RJITProcess >> gtProfileFor: aView [
	<gtView>
	^ self profile gtProfileFor: aView

]

{ #category : #'instance creation' }
RJITProcess >> gtVMProfilesFor: aView [
	<gtView>
	| profiles |
	profiles := RJITProfileList withAll: (self vmprofiles collect: #profile).
	^ (profiles subjectViewTitled: 'VMProfiles' translated subjectName: 'VMProfile' translated onView: aView) priority: 20
]

{ #category : #accessing }
RJITProcess >> label: arg1 [
	self shouldBeImplemented
]

{ #category : #accessing }
RJITProcess >> name [
	^ name
]

{ #category : #accessing }
RJITProcess >> name: aName [
	name := aName
]

{ #category : #printing }
RJITProcess >> printOn: aStream [
	(self name isNil or: [ name size = 0 ])
		ifTrue: [ super printOn: aStream ]
		ifFalse: [ aStream nextPutAll: self class name, ' ', self name ].

]

{ #category : #accessing }
RJITProcess >> profile [
	^ RJITProfile of: self aggregating: (self vmprofiles collect: #profile)
]

{ #category : #testing }
RJITProcess >> test [
	^{
		self gtHotTracesFor: GtPhlowView empty.
		self gtProfileFor: GtPhlowView empty.
		self gtVMProfilesFor: GtPhlowView empty.
		self traces collect: #test.
		self vmprofiles collect: #test.
	}.
]

{ #category : #'text dump' }
RJITProcess >> textDumpInDirectory: aFileReferenceOrPath [
	| dir |
	dir := aFileReferenceOrPath asFileReference.
	dir ensureDeleteAll; ensureCreateDirectory.
	Transcript show: 'Dumping traces: '.
	self traces do: [ :trace |
		Transcript show: trace traceno asString, ' '; flush.
		trace textDumpInDirectory: dir / 'trace' / trace traceno asString ].
	Transcript cr.
	self vmprofiles
		ifEmpty: [ 
			Transcript show: '(No vmprofile data found)'; cr. ]
		ifNotEmpty: [
			Transcript show: 'Dumping vmprofiles: '.
			self vmprofiles do: [ :prof |
				Transcript show: prof name, ' '; flush.
				prof textDumpInDirectory: dir / 'vmprofile'. ].
			Transcript cr. ].

]

{ #category : #accessing }
RJITProcess >> totalSamples [
	vmprofiles isEmpty ifTrue: [ ^0 ].
	^ vmprofiles sum: #total

]

{ #category : #accessing }
RJITProcess >> totalSamplesFor: trace [
	vmprofiles ifEmpty: [ ^0 ]. 
	^ vmprofiles sum: [ :p | (p trace: trace) all]
]

{ #category : #accessing }
RJITProcess >> trace: traceno [
	^ self traces at: traceno

]

{ #category : #accessing }
RJITProcess >> traceProfiles [
	| traceVMProfiles |
	traceVMProfiles := self vmprofiles collect: #traceProfiles.
	^RJITProfileList withAll: (self traces collect: [ :trace |
		RJITProfile of: trace aggregating: (traceVMProfiles collect: [ :ps | ps at: trace traceno + 1 ]) ]).

]

{ #category : #accessing }
RJITProcess >> traces [
	^ auditLog traces
]

{ #category : #accessing }
RJITProcess >> vmProfile: aVMProfile named: name [ 
	vmprofiles ifNil: [ vmprofiles := RJITProcessProfile new. ].
	vmprofiles at: name put: aVMProfile.

]

{ #category : #'instance creation' }
RJITProcess >> vmprofilePathsUnder: dir [
	| paths |
	paths := OrderedCollection new.
	[ paths addAll: (dir / 'vmprofile') children ] on: FileSystemError do: [ "no vmprofile/ dir" ].
	paths addAll: (dir allChildrenMatching: '*.vmprofile').
	^ paths

]

{ #category : #accessing }
RJITProcess >> vmprofiles [
	^ vmprofiles
]
