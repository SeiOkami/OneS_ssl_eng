# OneS SSL World Edition

The repository is used as the main configuration for developing universal extensions

Differences of the fork from the main project:
1. changed platform version in [file](https://github.com/SeiOkami/OneS_ssl_eng/blob/master/configuration/DT-INF/PROJECT.PMF)
2. Added [extension](https://github.com/SeiOkami/OneS_ssl_eng/tree/master/configuration.%D0%A0%D0%B0%D1%81%D1%88%D0%B8%D1%80%D0%B5%D0%BD%D0%B8%D0%B5%D0%94%D0%BB%D1%8F%D0%97%D0%B0%D0%BF%D1%83%D1%81%D0%BA%D0%B0%D0%98%D0%91) correcting the SSL to be able to create IS from the project itself

To use the repository you need to:

1. import the project from the repository into EDT
2. Create a new base and load the configuration from the project
3. Go to the configurator and disable all the checkboxes in the "StartEmptyBase" extension except "Active"
4. Go into enterprise mode and wait for the initial filling to complete

Now you can create your own universal extensions and processing on the basis of this project.
