Models for the Tutorial on CellML, OpenCOR & the Physiome Model Repository
==========================================================================

In this workspace we have the model and simulation experiment descriptions for the examples used in the tutorial on CellML, OpenCOR & the Physiome Model Repository created by Peter Hunter. The latest version of the tutorial itself is available at: http://tutorial-on-cellml-opencor-and-pmr.readthedocs.org/. This tutorial is also utilised as part of the `Computational Physiology <http://dtp-compphys.readthedocs.org>`_ module of the `MedTech CoRE <http://www.cmdt.org.nz>`_ `Doctoral Training Program <https://www.cmdt.org.nz/dtp>`_.

While the tutorial often leads the reader through creating these models from the beginning, here we provide the complete models and associated simulation experiments. As expected from the title of the tutorial, the models themselves are encoded in the `CellML <https://cellml.org>`_ format. The simulation experiments are encoded in the `SED-ML <http://sed-ml.org>`_ format and where possible we link directly to them to enable the user to simply launch them directly in `OpenCOR <http://opencor.ws>`_ from the repository (and also from within the tutorial documentation).

.. contents::
   :backlinks: top

Van der Pol oscillator
----------------------

Used in the *Create and run a simple CellML model: editing and simulation* section of the tutorial, the classical `Van der Pol oscillator <vanderpol.cellml/view>`_ is the first model described in the tutorial. The simulation experiment for this model described in the tutorial can be obtained by loading the `corresponding SED-ML document <vanderpol.sedml>`__ into OpenCOR and executing the simulation. The results of which are shown below.

.. image:: screenshots/vanderpol.png
   :width: 85%
   :alt: Screenshot illustrating the results of executing the Van der Pol simulation experiment in OpenCOR.

Exponential decay: A simple first order ODE
-------------------------------------------

Used as the simplest example of a first order differential equation, this `model <Firstorder.cellml/view>`_ consists of a `single equation <Firstorder.cellml/cellml_math>`_. One of the simulation experiments for this model described in the tutorial can be obtained by loading the `corresponding SED-ML document <Firstorder.sedml>`__ into OpenCOR and executing the simulation.

The Lorenz attractor
--------------------

The `Lorenz attractor <lorenz.cellml/view>`__ model is used in the tutorial as both an example of interesting dynamics and an illustration of the encoding of a third order differential equation as `three first order equations <lorenz.cellml/cellml_math>`__ in CellML. The figure below illustrates the results obtain by loading the `corresponding SED-ML document <lorenz.sedml>`__ into OpenCOR and executing the simulation.

.. image:: screenshots/lorenz.png
   :width: 85%
   :alt: Screenshot illustrating the results of executing the Lorenz attractor simulation experiment in OpenCOR.
   
Gating kinetics explained
-------------------------

The *A model of ion channel gating and current: Introducing CellML units* section in the tutorial introduces the concept of units in CellML models, and along the way provides an explanation of gating kinetics that are common when investigating ion channel behaviour (at least those channels which are voltage senstitive). As such, `this model <SimpleFirstOrderEqn.cellml/view>`__ provides a neat little toy for investigating the formulation of traditional ion channel models. Once again, the `corresponding SED-ML document <SimpleFirstOrderEqn.sedml>`__ is available to help get the reader started.

The Hodgkin & Huxley potassium and sodium channels
--------------------------------------------------

In the tutorial, the Hodgkin & Huxley `potassium channel <potassium_ion_channel.cellml/view>`__ and `sodium channel <sodium_ion_channel.cellml/view>`__ are used as the examples illustrating core CellML concepts. As these models get more complex, they are also a great example demonstrating the utility of providing SED-ML alongside the model, as shown with the results presented in the figure below.

.. image:: screenshots/potassium_channel.png
   :width: 85%
   :alt: Screenshot illustrating the results of executing this potassium simulation experiment in OpenCOR.
