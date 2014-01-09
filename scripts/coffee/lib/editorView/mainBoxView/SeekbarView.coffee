Foxie = require 'foxie'

module.exports = class SeekbarView

	constructor: (@mainBox) ->

		@clicks = @mainBox.editor.clicks

		@model = @mainBox.editor.model.timeControl

		@timelineLength = @model.timelineLength

		@model.on 'length-change', => do @_updateTimelineLength

		do @_prepareNode

		do @_prepareGrid

		do @_prepareSeeker

		do @_prepareFocus

		do @_resetSpace

		@mainBox.on 'width-change', => do @_resetSpace

	_prepareNode: ->

		@node = Foxie('.timeflow-seekbar')
		.putIn(@mainBox.node)

	_prepareGrid: ->

		@grid = Foxie('.timeflow-seekbar-timeGrid').putIn @mainBox.node

		@gridLegends = []

		for i in [0..parseInt(screen.width / 75)]

			@gridLegends.push Foxie('.timeflow-seekbar-timeGrid-legend').putIn(@grid)

		return

	_redoTimeGrid: ->

		focus = @model.getFocusArea()

		for legend, i in @gridLegends

			curX = i * 75 + 37.5

			w = curX / @_width

			w *= focus.duration

			w += focus.from

			w /= 1000

			legend.node.innerHTML = w.toFixed(2)

		return

	_prepareSeeker: ->

		@seeker = Foxie('.timeflow-seekbar-seeker')
		.moveZ(1)
		.putIn(@node)

		@model.on 'time-change', => do @_repositionSeeker

		wasPlaying = no

		@clicks.onDrag(@seeker)

		.onDown =>

			document.body.style.cursor = getComputedStyle(@seeker.node).cursor

			wasPlaying = @model.isPlaying()

			@model.pause() if wasPlaying

		.onUp =>

			document.body.style.cursor = ''

			if wasPlaying then @model.play()

		.onDrag (e) =>

			@_moveSeekerRelatively e.relX

		return

	_prepareFocus: ->

		do @_prepareFocusLeft

		do @_prepareFocusRight

		do @_prepareFocusStrip

		@model.on 'focus-change', =>

			do @_repositionElements

	_prepareFocusLeft: ->

		@focusLeftNode = Foxie('.timeflow-seekbar-focus-left')
		.moveZ(1)
		.set('left', 0)
		.putIn(@node)

		@clicks.onDrag(@focusLeftNode)

		.onDown =>

			document.body.style.cursor = getComputedStyle(@focusLeftNode.node).cursor

		.onUp =>

			document.body.style.cursor = ''

		.onDrag (e) =>

			@_moveFocusLeftInWindowSpace e.relX

	_prepareFocusRight: ->

		@focusRightNode = Foxie('.timeflow-seekbar-focus-right')
		.moveZ(1)
		.set('left', 0)
		.putIn(@node)

		@clicks.onDrag(@focusRightNode)

		.onDown =>

			document.body.style.cursor = getComputedStyle(@focusRightNode.node).cursor

		.onUp =>

			document.body.style.cursor = ''

		.onDrag (e) =>

			@_moveFocusRightInWindowSpace e.relX

	_prepareFocusStrip: ->

		@focusStripNode = Foxie('.timeflow-seekbar-focus-strip')
		.moveZ(-3)
		.css('width', '300px')
		.putIn(@node)

	_moveFocusLeftInWindowSpace: (x) ->

		focus = @model.getFocusArea()

		curWinPos = @focusLeftNode.get('left')

		nextWinPos = curWinPos + x

		# the from part
		nextFrom = nextWinPos / @_width * @timelineLength

		if nextFrom < 0

			nextFrom = 0

		# and the next to
		nextTo = focus.to

		if nextTo - nextFrom < 1000

			nextTo = nextFrom + 1000

		if nextTo > @timelineLength

			nextTo = @timelineLength

		# update the model
		@model.changeFocusArea nextFrom, nextTo

		# if the seeker is before the new from
		if nextFrom > @model.t

			# put it on the new from
			@model.tick nextFrom

		# if seeker is after the new focused area
		if nextTo < @model.t

			# put it on the end of the new focused area
			@model.tick nextTo

		return

	_moveFocusRightInWindowSpace: (x) ->

		focus = @model.getFocusArea()

		curWinPos = @focusRightNode.get('left')

		nextWinPos = curWinPos + x

		# the to part
		nextTo = nextWinPos / @_width * @timelineLength

		if nextTo > @timelineLength

			nextTo = @timelineLength

		if nextTo < 1000

			nextTo = 1000

		# and the next to
		nextFrom = focus.from

		if nextTo - nextFrom < 1000

			nextFrom = nextTo - 1000

		if nextFrom < 0

			nextFrom = 0

		# update the model
		@model.changeFocusArea nextFrom, nextTo

		# if the seeker is before the new from
		if @model.t > nextTo

			# put it on the new from
			@model.tick nextTo

		# if seeker is after the new focused area
		if nextFrom > @model.t

			# put it on the end of the new focused area
			@model.tick nextFrom

		return

	_resetSpace: ->

		@_width = @mainBox.width

		do @_repositionElements

	_repositionElements: ->

		do @_repositionSeeker

		do @_repositionFocus

		do @_redoTimeGrid

	_repositionSeeker: ->

		t = @model.t

		focus = @model.getFocusArea()

		rel = (t - focus.from) / focus.duration

		curSeekerPos = parseInt @_width * rel

		@seeker
		.moveXTo(curSeekerPos)
		.set('left', curSeekerPos)

		return

	_moveSeekerRelatively: (x) ->

		toPos = @seeker.get('left') + x

		focus = @model.getFocusArea()

		t = (toPos / @_width * focus.duration) + focus.from

		t = 0 if t < 0

		t = @timelineLength if t > @timelineLength

		@model.tick t

		return

	_repositionFocus: ->

		focus = @model.getFocusArea()

		left = parseInt (focus.from / @timelineLength) * @_width

		@focusLeftNode
		.moveXTo(left)
		.set('left', left)

		right = parseInt ((focus.from + focus.duration) / @timelineLength) * @_width

		@focusRightNode
		.moveXTo(right)
		.set('left', right)

		@focusStripNode
		.moveXTo(left)
		.css('width', (right - left) + 'px')

		return

	_updateTimelineLength: ->

		@timelineLength = @model.timelineLength

		do @_repositionElements