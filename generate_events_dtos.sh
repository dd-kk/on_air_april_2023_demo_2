rm -rf src
mkdir src
cd src
rm *
swagger-codegen generate -l swift5 -i ../events.yaml
mv SwaggerClient/Classes/Swaggers/Models/* .
rm -rf SwaggerClient
rm Cartfile
rm SwaggerClient.podspec
rm git_push.sh
rm .gitignore
rm -rf .swagger-codegen
rm .swagger-codegen-ignore
cd ..