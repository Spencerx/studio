"
I represent a list of Snabb processes.

I make the processes easy to compare and inspect.
"
Class {
	#name : #SnabbProcessList,
	#superclass : #RJITProcessList,
	#category : #'Studio-Snabb'
}

{ #category : #dumping }
SnabbProcessList >> textDumpInDirectory: aDirectory [
	self do: [ :process | process textDumpInDirectory: aDirectory ]
]
