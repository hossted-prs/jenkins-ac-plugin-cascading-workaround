/*
FIXME: This script is a workaround for the issue with parameter value rendering
       for cascading parameters in the Jenkins pipeline build page.
       The temporary solution to the problem is to manually trigger the forced
       consecutive update of the dependent parameters on both the initial load
       of the page, as well as on the change of the parent parameter value.
       This will ensure that the parameter values are correctly propagated and
       displayed in the Jenkins pipeline build page.
       The script behavior might break in the future under the following
       conditions:
       * The exposed Active Choices browser JS API changes
         (`window.UnoChoice` object)
       * The structure of the cascade parameters changes
         (`window.UnoChoice.cascadeParameters` array)
       * The use and / or structure of the logging messages in the
         `UnoChoice.js` script changes
       * The name or the path of this JavaScript file changes
        (inside the Jenkins plugin bundle)
*/
document.addEventListener("DOMContentLoaded", async () => {
  /* #region Constant variable definitions. */
  const updateTimeout = 5000;
  const isHiddenDuringUpdate = false;
  /* #endregion. */
  /* #region Function definitions. */
  /**
   * Pauses execution for a specified amount of time.
   *
   * @param {number} delay - The amount of time to pause in milliseconds.
   * @returns {Promise<void>} A promise that resolves after the specified delay.
   */
  const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay));
  /**
   * Performs a topological sort on the given cascade parameters.
   *
   * This implementation is based on Kahn's algorithm.
   *
   * @param {Array<Object>} cascadeParams - The cascade parameters to be sorted.
   * @returns {Array<Object>} - The cascade parameters sorted in topological
   *                            order.
   */
  const topologicalSortParams = (cascadeParams) => {
    /* Initialize data structures. */
    const inDegree = new Map();
    const adjList = new Map();
    const paramMap = new Map();
    const result = [];

    /* Initialize `inDegree` and adjList for all `cascadeParameters`. */
    cascadeParams.forEach((param) => {
      const { paramName } = param;
      if (!inDegree.has(paramName)) {
        /* Set in-degree to 0 on first appearance. */
        inDegree.set(paramName, 0);
        /* Initialize empty adjacency list. */
        adjList.set(paramName, []);
        /* Map paramName to param object. */
        paramMap.set(paramName, param);
      }
    });

    /* Build the graph and compute in-degrees. */
    cascadeParams.forEach((param) => {
      const { paramName } = param;
      /* Dependencies. */
      const refParams = param.referencedParameters;

      refParams.forEach((refParam) => {
        const refParamName = refParam.paramName;

        /*
        Ensure referenced parameter is tracked, even if not in
        `cascadeParameters`
        */
        if (!inDegree.has(refParamName)) {
          /* Initialize in-degree to 0. */
          inDegree.set(refParamName, 0);
          /* Initialize empty adjacency list. */
          adjList.set(refParamName, []);
          /* Map `refParamName` to `refParam` object. */
          paramMap.set(refParamName, refParam);
        }

        /* Add the dependency: `refParamName` -> `paramName`. */
        adjList.get(refParamName).push(paramName);
        /* Increase in-degree of `paramName`. */
        inDegree.set(paramName, (inDegree.get(paramName) || 0) + 1);
      });
    });

    /* Queue for objects with in-degree 0 (no dependencies). */
    const queue = [];
    inDegree.forEach((degree, paramName) => {
      if (degree === 0) {
        queue.push(paramName);
      }
    });

    /* Process nodes with in-degree 0. */
    while (queue.length > 0) {
      /* Get the next node to process. */
      const paramName = queue.shift();
      /* Add it to the topologically sorted result. */
      result.push(paramMap.get(paramName));

      /*
      For each node that depends on the current node, reduce its in-degree.
      */
      adjList.get(paramName).forEach((dependentParam) => {
        inDegree.set(dependentParam, inDegree.get(dependentParam) - 1);

        /* If in-degree becomes 0, add it to the queue. */
        if (inDegree.get(dependentParam) === 0) {
          queue.push(dependentParam);
        }
      });
    }

    /* Check if there are unresolved dependencies (cycle detection). */
    if (result.length !== inDegree.size) {
      console.warn("There may be a cycle or unresolved dependencies.");
    }

    return result;
  };
  /**
   * Retrieves the dependent parameters for a given parameter.
   *
   * @param {object} param - The parameter to find dependencies for.
   * @param {Array<object>} sortedParams - The array of sorted parameters.
   * @returns {Array<object>} - The array of dependent parameters.
   */
  const getDependentParams = (param, sortedParams) =>
    sortedParams.filter(
      (p) =>
        p.referencedParameters &&
        p.referencedParameters.some((ref) => ref.paramName === param.paramName)
    );
  /**
   * Retrieves the remaining parameters after the specified parameter in the
   * `sortedParams` array.
   *
   * @param {object} param - The parameter to find the remaining parameters after.
   * @param {Array<object>} sortedParams - The array of sorted parameters.
   * @returns {Array<object>} - The remaining parameters after the specified
   *                            parameter.
   */
  const getRemainingParams = (param, sortedParams) => {
    const index = sortedParams.findIndex(
      (p) => p.paramName === param.paramName
    );
    if (index === -1) {
      return [];
    }
    return sortedParams.slice(index + 1);
  };
  /**
   * Safely updates a parameter and its dependent parameters.
   *
   * This function ensures that the parameter and its dependent parameters are
   * updated sequentially by hooking into the console log calls, parsing the
   * log messages, and, thereby, tracking the update of dependent parameters.
   *
   * @param {Object} param - The parameter object to be updated.
   * @param {Array<Object>} sortedParams - The list of sorted parameter objects.
   * @returns {Promise<void>} A promise that resolves when the update process
   *                          is complete.
   */
  const updateSafe = async (param, sortedParams) => {
    /* Get the dependent parameter names. */
    const dependentParamNames = getDependentParams(param, sortedParams).map(
      (p) => p.paramName
    );
    /* Initialize local variables. */
    const statusMap = new Map();
    dependentParamNames.forEach((dependentParamName) =>
      statusMap.set(dependentParamName, false)
    );
    let currentPair = [];
    /* Backup the original `console.log()` function. */
    const consoleLogOrig = console.log;
    /* Override the `console.log()` function with update-tracking logic. */
    console.log = (...args) => {
      consoleLogOrig(...args);
      if (typeof args[0] === "string") {
        const updatingMatch = args[0].match(/^Updating (\S+) from (\S+)$/);
        if (updatingMatch) {
          const [_, depParam, refParam] = updatingMatch;
          currentPair = [depParam, refParam];
          return;
        }
        if (currentPair.length === 0) {
          return;
        }
        const retrievedMatch = args[0].match(
          /^Values retrieved from Referenced Parameters:/
        );
        if (retrievedMatch) {
          const [depParam, refParam] = currentPair;
          if (param.paramName === refParam && statusMap.has(depParam)) {
            statusMap.set(depParam, true);
          }
          currentPair = [];
          return;
        }
        /*
        TODO: Decide do we want to reset the tracked parameter(s) on unrelated
              log messages.
        */
        // currentPair = [];
      }
    };
    param.update && param.update();

    const startTime = Date.now();
    while (
      [...statusMap.values()].some((status) => status === false) &&
      !!param.update
    ) {
      if (Date.now() - startTime >= updateTimeout) {
        console.warn(
          `
            Update timeout exceeded for parameter: ${param.paramName}
            Dependent parameters: ${JSON.stringify(dependentParamNames)}
            Status map: ${JSON.stringify([...statusMap])}
          `
        );
        break;
      }
      await sleep(100);
    }
    console.log = consoleLogOrig;
  };
  /**
   * Main function to initialize and handle parameter updates.
   *
   * This function sets up event listeners for parameter changes and ensures that
   * dependent parameters are updated sequentially. It also handles the visibility
   * of the panel and logs additional information to the console.
   */
  const main = async () => {
    if (isHiddenDuringUpdate) {
      const panel = document.querySelector("#main-panel, .app-page-body");
      panel.style.visibility = "hidden";
    }

    /* Sort parameters topologically. */
    const sortedParams = topologicalSortParams(UnoChoice.cascadeParameters);

    /* Force consecutive update of all parameters in a correct order. */
    for (const param of sortedParams) {
      if (param.referencedParameters) {
        await updateSafe(param, sortedParams);
      }
    }

    /*
    Add event listeners to dropdown / `select` elements which will trigger
    consecutive updates of dependent parameters in a correct order.
    */

    sortedParams.forEach((param) => {
      if (param.paramElement && param.paramElement.tagName === "SELECT") {
        param.paramElement.addEventListener("change", async () => {
          const remainingParams = getRemainingParams(param, sortedParams);

          for (const remainingParam of remainingParams) {
            await updateSafe(remainingParam, sortedParams);
          }
        });
      }
    });

    if (isHiddenDuringUpdate) {
      panel.style.visibility = "visible";
    }

    await sleep(2000);

    console.warn(
      `
        Additional logic has been appended to the \`UnoChoice.js\` script which
        hooks to the \`DOMContentLoaded\` event. The logic contains a workaround
        for the issue with the parameter value rendering for cascading parameters
        in the Jenkins pipeline build page.
      `
    );
  };
  /* #endregion. */
  /* #region Execution. */
  await main();
  /* #endregion. */
});
