import Project, {Conf} from '$tl/Project/Project'
import TimelineInstance from '$tl/timelines/TimelineInstance'
import {validateAndSanitiseSlashedPathOrThrow} from '$tl/handy/slashedPaths'
import {InvalidArgumentError} from '$tl/handy/errors'
import {OnDiskState, $OnDiskState} from '$tl/Project/store/types'
import {userFacingReoprter} from '$shared/ioTypes/userFacingReporter'
import projectsSingleton from '$tl/Project/projectsSingleton'
import TheatreJSTimelineInstance from '$tl/facades/TheatreJSTimelineInstance'
import userReadableTypeOfValue from '$shared/utils/userReadableTypeOfValue';

const projectsWeakmap = new WeakMap<TheatreJSProject, Project>()

// User-facing facade for Project
export default class TheatreJSProject {
  // static name = 'Project'
  constructor(id: string, config: Conf = {}) {
    if (projectsSingleton.has(id)) {
      throw new InvalidArgumentError(
        `Looks like you're calling \`new Project("${id}")\` twice. If you're trying to make two separate projects, make sure to assign a unique ID to each of them. `,
      )
    }
    if ($env.NODE_ENV === 'development' || $env.tl.isCore === false) {
      validateProjectIdOrThrow(id)
    }
    if ($env.tl.isCore) {
      if (!config.state) {
        throw new InvalidArgumentError(
          `Argument config.state in new Project("${id}", config) cannot be empty in theatre/core. Read more at https://theatrejs.com/docs/state-persistence.html`,
        )
      }
      shallowValidateOnDiskState(id, config.state)
    } else {
      if (config.state) {
        deepValidateOnDiskState(id, config.state)
      }
    }
    projectsWeakmap.set(this, new Project(id, config))
  }

  getTimeline(_path: string, instanceId: string = 'default'): TheatreJSTimelineInstance {
    const path = validateAndSanitiseSlashedPathOrThrow(
      _path,
      'project.getTimeline',
    )

    return getProject(this).getTimeline(path, instanceId).facade
  }

  get adapters() {
    return getProject(this).adapters.facade
  }

  get ready() {
    return getProject(this).ready
  }

  get isReady() {
    return getProject(this).isReady()
  }
}

const getProject = (p: TheatreJSProject) =>
  (projectsWeakmap.get(p) as $IntentionalAny) as Project

const validateProjectIdOrThrow = (id: string) => {
  if (typeof id !== 'string') {
    throw new InvalidArgumentError(
      `Argument 'id' in \`new Project(id, ...)\` must be a string. Instead, it was ${userReadableTypeOfValue(id)}.`,
    )
  }

  const idTrimmed = id.trim()
  if (idTrimmed.length !== id.length) {
    throw new InvalidArgumentError(
      `Argument 'id' in \`new Project("${id}", ...)\` should not have surrounding whitespace.`,
    )
  }

  if (idTrimmed.length < 3) {
    throw new InvalidArgumentError(
      `Argument 'id' in \`new Project("${id}", ...)\` should be at least 3 characters long.`,
    )
  }
}

/**
 * Lightweight validator that only makes sure the state's definitionVersion is correct.
 * Does not do a thorough validation of the state.
 */
const shallowValidateOnDiskState = (projectId: string, s: OnDiskState) => {
  if (
    Array.isArray(s) ||
    s == null ||
    s.definitionVersion !== $env.tl.currentProjectStateDefinitionVersion
  ) {
    throw new InvalidArgumentError(
      `Error validating conf.state in new Project(${JSON.stringify(
        projectId,
      )}, conf). The state seems to be formatted in a way that is unreadable to Theatre.js. Read more at https://theatrejs.com/docs/state-persistence.html`,
    )
  }
}

/**
 * Does a thorough validation of the onDisk state.
 */
const deepValidateOnDiskState = (projectId: string, s: OnDiskState) => {
  const validationResult = $OnDiskState.validate(s)

  if (validationResult.isLeft()) {
    console.group(
      `Argument config.state in new Project("${projectId}", config) is invalid. Lean how to fix this at https://theatrejs.com/docs/state-persistence.html#troubleshooting`,
    )
    const errors = userFacingReoprter(validationResult)
    errors.forEach(e => console.log(e))
    console.groupEnd()

    throw new InvalidArgumentError(
      `Argument config.state in new Project("${projectId}", config) is invalid. Lean how to fix this at https://theatrejs.com/docs/state-persistence.html#troubleshooting`,
    )
  }
}

// @ts-ignore ignore
// ProjectFacade.name = 'Project'