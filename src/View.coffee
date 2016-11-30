
# We need to monkey patch these methods in, because subclasses of View might have already been made

origSetElement = View::setElement
origRemoveElement = View::removeElement
origSetDate = View::setDate
origTriggerDateRender = View::triggerDateRender
origForceEventsRender = View::forceEventsRender


View::isResourcesBound = false
View::isResourcesSet = false


# View Rendering
# --------------------------------------------------------------------------------------------------


View::setElement = ->
	promise = origSetElement.apply(this, arguments)
	@bindResources() # wait until after skeleton
	promise


View::removeElement = ->
	@unbindResources({ skipRerender: true })
	origRemoveElement.apply(this, arguments)


# Date Setting / Rendering
# --------------------------------------------------------------------------------------------------


View::setDate = ->
	isReset = @isDateSet

	# go first, before events bind (which might immediately request + render)
	if isReset and false
		@unsetResources({ skipUnrender: true })
		@calendar.resourceManager.fetchResources()

	origSetDate.apply(this, arguments)


View::triggerDateRender = ->
	processLicenseKey(
		@calendar.options.schedulerLicenseKey
		@el # container element
	)
	origTriggerDateRender.apply(this, arguments)


# Event Rendering
# --------------------------------------------------------------------------------------------------


View::forceEventsRender = (events) ->
	@whenResourcesSet().then => # wait for resource data, for coloring
		origForceEventsRender.call(this, events)


# Resource Binding
# --------------------------------------------------------------------------------------------------


View::bindResources = ->
	if not @isResourcesBound
		@isResourcesBound = true
		@rejectOn('resourcesUnbind', @requestResources()).then (resources) =>
			@listenTo @calendar.resourceManager,
				set: @setResources
				reset: @setResources
				unset: @unsetResources
				add: @addResource
				remove: @removeResource
			@setResources(resources)


View::unbindResources = (teardownOptions) ->
	if @isResourcesBound
		@isResourcesBound = false
		@stopListeningTo(@calendar.resourceManager)
		@unsetResources(teardownOptions)
		@trigger('resourcesUnbind')


View::requestResources = ->
	@calendar.resourceManager.getResources()


# Resource Setting
# --------------------------------------------------------------------------------------------------


View::setResources = (resources) ->
	isReset = @isResourcesSet
	@isResourcesSet = true

	if @isEventsRendered
		@requestEventsRerender() # event coloring might have changed

	if not isReset
		@trigger('resourcesSet')


View::unsetResources = (teardownOptions={}) ->
	if @isResourcesSet
		@isResourcesSet = false

		if @isEventsRendered and not teardownOptions.skipRerender
			@requestEventsRerender()

		@trigger('resourcesUnset')


View::whenResourcesSet = ->
	if @isResourcesSet
		Promise.resolve()
	else
		new Promise (resolve) =>
			@one('resourcesSet', resolve)


View::addResource = ->
	if @isEventsRendered
		@requestEventsRerender()


View::removeResource = ->
	if @isEventsRendered
		@requestEventsRerender()


View::requestResourcesRerender = ->
	if @isEventsRendered
		@requestEventsRerender()
