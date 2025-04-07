# trunk-ignore-all(checkov)
FROM swift:6.0

WORKDIR /app

COPY Package.swift .
COPY Package.resolved .
RUN swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build

CMD ["swift", "test"]
